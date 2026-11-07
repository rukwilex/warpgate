import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/data/direct_transfer.dart';
import 'package:warpgate_core/features/transfers/data/file_checksum.dart';
import 'package:warpgate_core/features/transfers/data/transfer_engine.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

class TransferScheduler {
  new({
    required this.store,
    required this.pool,
    required this.resolver,
    required this.broker,
    required this.hostOf,
    required this.settings,
    this.onChange,
    this.autoRun = true,
    bool Function(int pid)? isAlive,
    List<TransferJob> initial = const [],
  }) : _isAlive = isAlive ?? ((_) => false),
       jobs = initial;

  static const collection = 'transfers';
  static const historyLimit = 500;
  static const controlCollection = 'transfer_control';

  final DocumentStore store;
  final ConnectionPool pool;
  final EndpointResolver resolver;
  final InteractionBroker broker;
  final Host? Function(String? id) hostOf;
  final AppSettings Function() settings;
  final bool autoRun;
  final bool Function(int pid) _isAlive;
  void Function(List<TransferJob> jobs)? onChange;

  List<TransferJob> jobs;

  final Map<String, CancelToken> _tokens = {};
  final Set<String> _pauseRequested = {};
  final Map<String, DateTime> _lastPersist = {};
  final Map<String, bool> _hasSha256 = {};

  static Future<List<TransferJob>> load(DocumentStore store) async => [
    for (final json in await store.all(collection)) TransferJob.fromJson(json),
  ];

  static List<TransferJob> restore(
    List<TransferJob> stored,
    bool Function(int pid) isAlive,
  ) => [
    for (final job in stored)
      if (job.status != TransferStatus.running)
        job
      else if (job.ownerPid == null)
        job.copyWith(status: TransferStatus.queued)
      else if (isAlive(job.ownerPid!))
        job
      else
        job.copyWith(status: TransferStatus.paused, ownerPid: () => null),
  ];

  bool isForeign(TransferJob job) =>
      job.ownerPid != null && job.ownerPid != pid && _isAlive(job.ownerPid!);

  TransferJob? byId(String id) => jobs.firstWhereOrNull((job) => job.id == id);

  int get activeCount =>
      jobs.where((job) => job.status == TransferStatus.running).length;

  void _publish(List<TransferJob> next) {
    jobs = next;
    onChange?.call(next);
  }

  void mergeStored(List<TransferJob> stored) {
    final local = {
      for (final job in jobs)
        if (_tokens.containsKey(job.id)) job.id: job,
    };
    _publish(
      restore(stored, _isAlive)
          .map((job) => local[job.id] ?? job)
          .toList(),
    );
  }

  void _replace(
    String id,
    TransferJob Function(TransferJob job) change, {
    bool persist = false,
  }) {
    final index = jobs.indexWhere((job) => job.id == id);
    if (index < 0) return;
    final next = change(jobs[index]);
    _publish([...jobs]..[index] = next);
    final now = DateTime.now();
    final last = _lastPersist[id];
    final every = next.completedFiles.length > 2000
        ? const Duration(seconds: 15)
        : const Duration(seconds: 2);
    if (persist || last == null || now.difference(last) > every) {
      _lastPersist[id] = now;
      unawaited(store.put(collection, id, next.toJson(), at: next.createdAt));
    }
    if (persist && next.status.isFinished) {
      _lastPersist.remove(id);
      _trimHistory();
    }
  }

  void _trimHistory() {
    final finished = [
      for (final job in jobs)
        if (job.status.isFinished) job,
    ];
    if (finished.length <= historyLimit) return;
    finished.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final drop = {
      for (final job in finished.take(finished.length - historyLimit)) job.id,
    };
    _publish([
      for (final job in jobs)
        if (!drop.contains(job.id)) job,
    ]);
    for (final id in drop) {
      unawaited(store.delete(collection, id));
    }
  }

  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    bool isDirectory = false,
    TransferMode mode = TransferMode.stream,
    String origin = 'user',
    bool move = false,
    bool verify = false,
    int? ownerPid,
    bool start = true,
  }) {
    final job = TransferJob(
      move: move,
      verify: verify,
      id: Ids.next(),
      source: source,
      target: target,
      name: name,
      isDirectory: isDirectory,
      mode: mode,
      createdAt: DateTime.now(),
      origin: origin,
      ownerPid: ownerPid,
    );
    _publish([...jobs, job]);
    unawaited(store.put(collection, job.id, job.toJson(), at: job.createdAt));
    if (start) pump();
    return job.id;
  }

  void pump() {
    if (!autoRun) return;
    final limit = settings().transferConcurrency.clamp(1, 16);
    var running = activeCount;
    for (final job in jobs.where(
      (job) => job.status == TransferStatus.queued && job.ownerPid == null,
    ).toList()) {
      if (running >= limit) break;
      running += 1;
      unawaited(run(job.id));
    }
  }

  Future<TransferJob> run(
    String id, {
    ConflictResolution? forced,
    ConflictPolicy? policy,
    Duration? controlPoll,
  }) async {
    final token = CancelToken();
    _tokens[id] = token;
    Timer? poller;
    if (controlPoll != null) {
      poller = Timer.periodic(controlPoll, (_) => unawaited(_poll(id)));
    }
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
    final held = <String>[];
    try {
      for (final hostId in {job.source.hostId, job.target.hostId}.nonNulls) {
        try {
          await pool.client(hostId);
          pool.retain(hostId);
          held.add(hostId);
        } on Object {
          continue;
        }
      }
      if (job.mode == TransferMode.direct) {
        await _runDirect(job, token);
      } else {
        await TransferEngine(
          endpointFor: resolver.resolve,
          askConflict: broker.ask,
          checksum: _checksum,
        ).run(
          job,
          update: (change) => _replace(id, change),
          cancel: token,
          policy: policy ?? settings().conflictPolicy,
          forced: forced,
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
          ownerPid: () => null,
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
          ownerPid: () => null,
        ),
        persist: true,
      );
    } on Object catch (error, stack) {
      AppLog.instance.error('transfer', 'Transfer $id failed: $error', stack);
      <String?>{
        job.source.hostId,
        job.target.hostId,
      }.nonNulls.forEach(resolver.invalidate);
      _replace(
        id,
        (job) => job.copyWith(
          status: TransferStatus.failed,
          bytesPerSecond: 0,
          error: () => error is FileOperationException
              ? error.message
              : SshErrorText.describe(error),
          finishedAt: DateTime.now,
          ownerPid: () => null,
        ),
        persist: true,
      );
    } finally {
      held.forEach(pool.release);
      poller?.cancel();
      _tokens.remove(id);
      pump();
    }
    return byId(id)!;
  }

  Future<void> _poll(String id) async {
    final control = await store.get(controlCollection, id);
    if (control == null) return;
    await store.delete(controlCollection, id);
    if (control['action'] == 'pause') _pauseRequested.add(id);
    _tokens[id]?.cancel();
  }

  Future<String?> _checksum(String? hostId, String path) async {
    if (hostId == null) return FileChecksum.local(path);
    if (_hasSha256[hostId] == false) return null;
    final quoted = KeyCodec.shellQuote(path);
    final result = await pool.exec(
      hostId,
      'if command -v sha256sum >/dev/null 2>&1; then sha256sum -- $quoted; '
      'elif command -v shasum >/dev/null 2>&1; then shasum -a 256 -- $quoted; '
      'fi',
      timeout: const Duration(minutes: 30),
    );
    final digest = FileChecksum.parse(result.stdout);
    _hasSha256[hostId] = digest != null;
    return digest;
  }

  Future<void> _runDirect(TransferJob job, CancelToken token) async {
    final source = hostOf(job.source.hostId);
    final target = hostOf(job.target.hostId);
    if (source == null || target == null) {
      throw const FileOperationException('Both hosts must still be saved');
    }
    final direct = DirectTransfer(pool);
    final probe = await direct.probe(source, target);
    if (!probe.reachable) {
      throw FileOperationException(
        probe.reason ?? 'Direct mode is not available',
      );
    }
    final meter = SpeedMeter();
    await pool.withOperation(
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

  void _control(String id, String action) => unawaited(
    store.put(controlCollection, id, {'action': action}),
  );

  void pause(String id) {
    final job = byId(id);
    if (job != null && isForeign(job)) return _control(id, 'pause');
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
      (job) => job.copyWith(
        status: TransferStatus.queued,
        error: () => null,
        ownerPid: () => null,
      ),
      persist: true,
    );
    pump();
  }

  void cancel(String id) {
    final job = byId(id);
    if (job != null && isForeign(job)) return _control(id, 'cancel');
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
        ownerPid: () => null,
      ),
      persist: true,
    );
    pump();
  }

  void retryFailed() {
    for (final job in jobs
        .where((job) => job.status == TransferStatus.failed)
        .toList()) {
      retry(job.id);
    }
  }

  void pauseAll() {
    for (final job in jobs.where((job) => job.status.isActive).toList()) {
      pause(job.id);
    }
  }

  int clearFinished() {
    final finished = jobs
        .where((job) => job.status.isFinished)
        .map((job) => job.id)
        .toList();
    _publish(jobs.where((job) => !job.status.isFinished).toList());
    for (final id in finished) {
      unawaited(store.delete(collection, id));
    }
    return finished.length;
  }
}
