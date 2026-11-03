import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/platform/native.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

final initialTransfersProvider = Provider<List<TransferJob>>((ref) => const []);

final transferQueueProvider =
    NotifierProvider<TransferQueue, List<TransferJob>>(TransferQueue.new);

class TransferQueue extends Notifier<List<TransferJob>> {
  static const String collection = TransferScheduler.collection;

  late TransferScheduler _scheduler;

  @override
  List<TransferJob> build() {
    final restored = TransferScheduler.restore(
      ref.read(initialTransfersProvider),
      Native.isProcessAlive,
    );
    _scheduler = TransferScheduler(
      store: ref.read(documentStoreProvider),
      pool: ref.read(connectionPoolProvider),
      resolver: ref.read(endpointResolverProvider),
      broker: ref.read(interactionBrokerProvider),
      hostOf: (id) => ref.read(hostsProvider).value?.host(id),
      settings: () => ref.read(settingsProvider),
      isAlive: Native.isProcessAlive,
      initial: restored,
      onChange: (jobs) => state = jobs,
    );
    unawaited(Future.microtask(_scheduler.pump));
    return restored;
  }

  static Future<List<TransferJob>> load(DocumentStore store) =>
      TransferScheduler.load(store);

  Future<void> reload() async {
    _scheduler.mergeStored(await load(ref.read(documentStoreProvider)));
    _scheduler.pump();
  }

  TransferJob? byId(String id) => _scheduler.byId(id);

  int get activeCount => _scheduler.activeCount;

  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    bool isDirectory = false,
    TransferMode mode = TransferMode.stream,
    String origin = 'user',
    bool move = false,
  }) => _scheduler.enqueue(
    source: source,
    target: target,
    name: name,
    isDirectory: isDirectory,
    mode: mode,
    origin: origin,
    move: move,
  );

  void pause(String id) => _scheduler.pause(id);

  void resume(String id) => _scheduler.resume(id);

  void cancel(String id) => _scheduler.cancel(id);

  void retry(String id) => _scheduler.retry(id);

  void retryFailed() => _scheduler.retryFailed();

  void pauseAll() => _scheduler.pauseAll();

  void clearFinished() => _scheduler.clearFinished();

  void rescheduleAfterSettingsChange() => _scheduler.pump();
}
