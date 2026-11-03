import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/multi_exec/domain/multi_exec_run.dart';

class MultiExecRunner {
  const new(this._pool);

  static const defaultParallelism = 8;

  final ConnectionPool _pool;

  Future<ExecResult> runOne(
    String hostId,
    String command,
    Duration timeout,
  ) => _pool.exec(hostId, command, timeout: timeout);

  Future<MultiExecRun> run(
    String command,
    List<String> hostIds, {
    Duration timeout = const Duration(seconds: 60),
    int parallelism = defaultParallelism,
    bool stopOnFailure = false,
    void Function(MultiExecRun run)? onUpdate,
    String? id,
  }) async {
    var current = MultiExecRun(
      id: id ?? Ids.next(),
      command: command,
      startedAt: DateTime.now(),
      timeout: timeout,
      runs: {for (final hostId in hostIds) hostId: HostRun(hostId: hostId)},
    );
    onUpdate?.call(current);
    void set(HostRun run) {
      current = current.update(run);
      onUpdate?.call(current);
    }

    final queue = [...hostIds];
    var stopped = false;
    Future<void> worker() async {
      while (queue.isNotEmpty && !stopped) {
        final hostId = queue.removeAt(0);
        set(HostRun(hostId: hostId, state: HostRunState.running));
        final result = await runOne(hostId, command, timeout);
        if (!result.succeeded && stopOnFailure) stopped = true;
        set(
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
    return current;
  }
}
