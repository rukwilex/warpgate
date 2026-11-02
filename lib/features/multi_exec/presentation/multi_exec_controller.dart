import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/util/ids.dart';
import 'package:warpgate/features/connection/data/connection_pool.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/multi_exec/domain/multi_exec_run.dart';

final multiExecProvider =
    NotifierProvider<MultiExecController, List<MultiExecRun>>(
      MultiExecController.new,
    );

class MultiExecController extends Notifier<List<MultiExecRun>> {
  static const parallelism = 8;

  @override
  List<MultiExecRun> build() => const [];

  MultiExecRun? byId(String id) =>
      state.where((run) => run.id == id).firstOrNull;

  Future<MultiExecRun> run(
    String command,
    List<String> hostIds, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final id = Ids.next();
    state = [
      MultiExecRun(
        id: id,
        command: command,
        startedAt: DateTime.now(),
        timeout: timeout,
        runs: {for (final hostId in hostIds) hostId: HostRun(hostId: hostId)},
      ),
      ...state,
    ];
    final pool = ref.read(connectionPoolProvider);
    final queue = [...hostIds];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final hostId = queue.removeAt(0);
        _set(id, HostRun(hostId: hostId, state: HostRunState.running));
        final result = await runOne(pool, hostId, command, timeout);
        _set(
          id,
          HostRun(
            hostId: hostId,
            state: result.succeeded
                ? HostRunState.succeeded
                : HostRunState.failed,
            result: result,
          ),
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < parallelism && i < hostIds.length; i++) worker(),
    ]);
    return byId(id)!;
  }

  static Future<ExecResult> runOne(
    ConnectionPool pool,
    String hostId,
    String command,
    Duration timeout,
  ) => pool.exec(hostId, command, timeout: timeout);

  void _set(String runId, HostRun run) {
    state = [
      for (final item in state)
        if (item.id == runId) item.update(run) else item,
    ];
  }

  void clear() => state = const [];
}
