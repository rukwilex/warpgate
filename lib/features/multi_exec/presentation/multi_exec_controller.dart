import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/multi_exec/data/multi_exec_runner.dart';
import 'package:warpgate_core/features/multi_exec/domain/multi_exec_run.dart';

final multiExecProvider =
    NotifierProvider<MultiExecController, List<MultiExecRun>>(
      MultiExecController.new,
    );

class MultiExecController extends Notifier<List<MultiExecRun>> {
  static const int parallelism = MultiExecRunner.defaultParallelism;

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
    return await MultiExecRunner(ref.read(connectionPoolProvider)).run(
      command,
      hostIds,
      timeout: timeout,
      id: id,
      onUpdate: (run) {
        state = state.any((item) => item.id == id)
            ? [
                for (final item in state)
                  if (item.id == id) run else item,
              ]
            : [run, ...state];
      },
    );
  }

  static Future<ExecResult> runOne(
    ConnectionPool pool,
    String hostId,
    String command,
    Duration timeout,
  ) => MultiExecRunner(pool).runOne(hostId, command, timeout);

  void clear() => state = const [];
}
