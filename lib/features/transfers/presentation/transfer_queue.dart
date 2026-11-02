import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/core/util/ids.dart';
import 'package:warpgate/features/connection/data/ssh_errors.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/transfers/data/direct_transfer.dart';
import 'package:warpgate/features/transfers/data/transfer_engine.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';

final initialTransfersProvider = Provider<List<TransferJob>>((ref) => const []);

final transferQueueProvider =
    NotifierProvider<TransferQueue, List<TransferJob>>(TransferQueue.new);

class TransferQueue extends Notifier<List<TransferJob>> {
  static const collection = 'transfers';

  final Map<String, CancelToken> _tokens = {};
  final Set<String> _pauseRequested = {};
  final Map<String, DateTime> _lastPersist = {};

  @override
  List<TransferJob> build() {
    final restored = [
      for (final job in ref.read(initialTransfersProvider))
        if (job.status == TransferStatus.running)
          job.copyWith(status: TransferStatus.queued)
        else
          job,
    ];
    unawaited(Future.microtask(_pump));
    return restored;
  }

  static Future<List<TransferJob>> load(DocumentStore store) async => [
    for (final json in await store.all(collection)) TransferJob.fromJson(json),
  ];

  TransferJob? byId(String id) => state.firstWhereOrNull((job) => job.id == id);

  int get activeCount =>
      state.where((job) => job.status == TransferStatus.running).length;

  void _replace(
    String id,
    TransferJob Function(TransferJob job) change, {
    bool persist = false,
  }) {
    final index = state.indexWhere((job) => job.id == id);
    if (index < 0) return;
    final next = change(state[index]);
    state = [...state]..[index] = next;
    final now = DateTime.now();
    final last = _lastPersist[id];
    if (persist ||
        last == null ||
        now.difference(last) > const Duration(seconds: 2)) {
      _lastPersist[id] = now;
      unawaited(
        ref
            .read(documentStoreProvider)
            .put(collection, id, next.toJson(), at: next.createdAt),
      );
    }
  }

  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    bool isDirectory = false,
    TransferMode mode = TransferMode.stream,
    String origin = 'user',
  }) {
    final job = TransferJob(
      id: Ids.next(),
      source: source,
      target: target,
      name: name,
      isDirectory: isDirectory,
      mode: mode,
      createdAt: DateTime.now(),
      origin: origin,
    );
    state = [...state, job];
    unawaited(
      ref
          .read(documentStoreProvider)
          .put(collection, job.id, job.toJson(), at: job.createdAt),
    );
    _pump();
    return job.id;
  }

  void _pump() {
    final limit = ref.read(settingsProvider).transferConcurrency.clamp(1, 16);
    var running = activeCount;
    for (final job
        in state.where((job) => job.status == TransferStatus.queued).toList()) {
      if (running >= limit) break;
      running += 1;
      unawaited(_run(job.id));
    }
  }

  Future<void> _run(String id) async {
    final token = CancelToken();
    _tokens[id] = token;
    _replace(
      id,
      (job) => job.copyWith(
        status: TransferStatus.running,
        startedAt: () => job.startedAt ?? DateTime.now(),
        error: () => null,
      ),
      persist: true,
    );
    final job = byId(id)!;
    try {
      if (job.mode == TransferMode.direct) {
        await _runDirect(job, token);
      } else {
        await _engine.run(
          job,
          update: (change) => _replace(id, change),
          cancel: token,
          policy: ref.read(settingsProvider).conflictPolicy,
        );
      }
      _replace(
        id,
        (job) => job.copyWith(
          status: TransferStatus.completed,
          doneBytes: job.totalBytes,
          bytesPerSecond: 0,
          finishedAt: DateTime.now,
          currentFile: () => null,
        ),
        persist: true,
      );
    } on TransferCancelled {
      final paused = _pauseRequested.remove(id);
      _replace(
        id,
        (job) => job.copyWith(
          status: paused ? TransferStatus.paused : TransferStatus.canceled,
          bytesPerSecond: 0,
          finishedAt: () => paused ? null : DateTime.now(),
        ),
        persist: true,
      );
    } on Object catch (error) {
      <String?>{
        job.source.hostId,
        job.target.hostId,
      }.nonNulls.forEach(ref.read(endpointResolverProvider).invalidate);
      _replace(
        id,
        (job) => job.copyWith(
          status: TransferStatus.failed,
          bytesPerSecond: 0,
          error: () => error is FileOperationException
              ? error.message
              : SshErrorText.describe(error),
          finishedAt: DateTime.now,
        ),
        persist: true,
      );
    } finally {
      _tokens.remove(id);
      _pump();
    }
  }

  TransferEngine get _engine => TransferEngine(
    endpointFor: ref.read(endpointResolverProvider).resolve,
    askConflict: ref.read(interactionBrokerProvider).ask,
  );

  Future<void> _runDirect(TransferJob job, CancelToken token) async {
    final hosts = ref.read(hostsProvider).value;
    final source = hosts?.host(job.source.hostId);
    final target = hosts?.host(job.target.hostId);
    if (source == null || target == null) {
      throw const FileOperationException('Both hosts must still be saved');
    }
    final direct = DirectTransfer(ref.read(connectionPoolProvider));
    final probe = await direct.probe(source, target);
    if (!probe.reachable) {
      throw FileOperationException(
        probe.reason ?? 'Direct mode is not available',
      );
    }
    final meter = SpeedMeter();
    await ref
        .read(connectionPoolProvider)
        .withOperation(
          source.id,
          (_) => direct.run(
            source: source,
            target: target,
            sourcePath: job.source.path,
            targetPath: job.target.path,
            tool: probe.tool!,
            cancel: token,
            onProgress: (fraction, speed) => _replace(
              job.id,
              (job) => job.copyWith(
                totalBytes: 1000,
                doneBytes: (fraction * 1000).round(),
                bytesPerSecond: speed > 0
                    ? speed
                    : meter.add((fraction * 1000).round()),
              ),
            ),
          ),
        );
  }

  void pause(String id) {
    final token = _tokens[id];
    if (token == null) {
      _replace(
        id,
        (job) => job.copyWith(status: TransferStatus.paused),
        persist: true,
      );
      return;
    }
    _pauseRequested.add(id);
    token.cancel();
  }

  void resume(String id) {
    _replace(
      id,
      (job) => job.copyWith(status: TransferStatus.queued, error: () => null),
      persist: true,
    );
    _pump();
  }

  void cancel(String id) {
    final token = _tokens[id];
    if (token != null) {
      token.cancel();
      return;
    }
    _replace(
      id,
      (job) => job.copyWith(
        status: TransferStatus.canceled,
        finishedAt: DateTime.now,
      ),
      persist: true,
    );
  }

  void retry(String id) {
    _replace(
      id,
      (job) => job.copyWith(
        status: TransferStatus.queued,
        error: () => null,
        finishedAt: () => null,
      ),
      persist: true,
    );
    _pump();
  }

  void retryFailed() {
    for (final job
        in state.where((job) => job.status == TransferStatus.failed).toList()) {
      retry(job.id);
    }
  }

  void pauseAll() {
    for (final job in state.where((job) => job.status.isActive).toList()) {
      pause(job.id);
    }
  }

  void clearFinished() {
    final finished = state
        .where((job) => job.status.isFinished)
        .map((job) => job.id)
        .toList();
    state = state.where((job) => !job.status.isFinished).toList();
    for (final id in finished) {
      unawaited(ref.read(documentStoreProvider).delete(collection, id));
    }
  }

  void rescheduleAfterSettingsChange() => _pump();
}
