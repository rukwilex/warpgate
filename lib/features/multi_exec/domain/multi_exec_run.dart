import 'package:flutter/foundation.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';

enum HostRunState { pending, running, succeeded, failed }

@immutable
class HostRun {
  const new({
    required this.hostId,
    this.state = HostRunState.pending,
    this.result,
  });

  final String hostId;
  final HostRunState state;
  final ExecResult? result;
}

enum RunFilter { all, failed, succeeded }

@immutable
class MultiExecRun {
  const new({
    required this.id,
    required this.command,
    required this.startedAt,
    required this.runs,
    this.timeout = const Duration(seconds: 60),
  });

  final String id;
  final String command;
  final DateTime startedAt;
  final Duration timeout;
  final Map<String, HostRun> runs;

  int get succeeded =>
      runs.values.where((run) => run.state == HostRunState.succeeded).length;

  int get failed =>
      runs.values.where((run) => run.state == HostRunState.failed).length;

  int get pending => runs.values
      .where(
        (run) =>
            run.state == HostRunState.pending ||
            run.state == HostRunState.running,
      )
      .length;

  bool get isDone => pending == 0;

  MultiExecRun update(HostRun run) => MultiExecRun(
    id: id,
    command: command,
    startedAt: startedAt,
    timeout: timeout,
    runs: {...runs, run.hostId: run},
  );

  List<HostRun> filtered(RunFilter filter) => [
    for (final run in runs.values)
      if (filter == RunFilter.all ||
          (filter == RunFilter.failed && run.state == HostRunState.failed) ||
          (filter == RunFilter.succeeded &&
              run.state == HostRunState.succeeded))
        run,
  ];
}
