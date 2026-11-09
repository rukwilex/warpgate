import 'dart:async';
import 'dart:io';

import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/transfers/data/file_checksum.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

abstract final class Progress {
  static String bar(TransferJob job, int width) {
    final fraction = job.fraction ?? 0;
    final filled = (fraction * width).round().clamp(0, width);
    final percent = (fraction * 100).round().toString().padLeft(3);
    final speed = job.bytesPerSecond > 0
        ? '  ${Format.bytes(job.bytesPerSecond.round())}/s'
        : '';
    return '${job.name}  [${'#' * filled}${'-' * (width - filled)}] $percent%  '
        '${Format.bytes(job.doneBytes)} of ${Format.bytes(job.totalBytes)}$speed';
  }
}

abstract final class TransferRunner {
  static Future<JsonMap?> run(
    CliContext context,
    ActionSpec action,
    WarpgateRuntime rt,
    TransferScheduler queue,
    List<String> ids, {
    required ConflictPolicy policy,
    ConflictResolution? forced,
    ({bool move, bool verify})? afterDirect,
  }) async {
    final output = context.output;
    final finished = <TransferJob>[];
    Timer? ticker;
    var drawn = false;
    if (output.showProgress) {
      ticker = Timer.periodic(ActionTimeouts.progressTick, (_) {
        final running = queue.jobs.where((job) => job.status == TransferStatus.running).firstOrNull;
        if (running == null) return;
        final width = stderr.hasTerminal ? (stderr.terminalColumns - 60).clamp(10, 40) : 30;
        output.raw('\r\x1B[2K${Progress.bar(running, width)}');
        drawn = true;
      });
    }
    final interrupt = ProcessSignal.sigint.watch().listen((_) {
      ids.forEach(queue.pause);
    });
    try {
      for (final id in ids) {
        var job = await queue.run(
          id,
          forced: forced,
          policy: policy,
          controlPoll: ActionTimeouts.transferPoll,
        );
        if (afterDirect != null && job.status == TransferStatus.completed) {
          await _finishDirect(rt, job, afterDirect);
          job = queue.byId(id)!;
        }
        finished.add(job);
      }
    } finally {
      ticker?.cancel();
      await interrupt.cancel();
      if (drawn) output.raw('\r\x1B[2K');
    }
    await rt.store.dataVersion();
    final failed = finished.where((job) => job.status == TransferStatus.failed).toList();
    final paused = finished.where((job) => job.status == TransferStatus.paused).toList();
    final result = {
      'transfers': [for (final job in finished) Json.transfer(rt, job)],
      'failed': failed.length,
    };
    if (output.json) {
      output.emit(action, result);
    } else {
      for (final job in finished) {
        if (job.status == TransferStatus.completed) {
          output.note('Copied ${job.name} (${Format.bytes(job.totalBytes)})');
        }
      }
      for (final job in failed) {
        output.raw('${output.red('error:')} ${job.name}: ${job.error}\n');
      }
      for (final job in paused) {
        output.note('Paused ${job.name}. Run warpgate transfers resume ${job.id.substring(0, 8)}');
      }
    }
    if (paused.isNotEmpty) throw ExitWith(ExitKind.interrupted.code);
    if (failed.isNotEmpty) {
      throw ExitWith(
        finished.length > 1 && failed.length < finished.length
            ? ExitKind.partial.code
            : ExitKind.general.code,
      );
    }
    throw const ExitWith(0);
  }

  static Future<void> _finishDirect(
    WarpgateRuntime rt,
    TransferJob job,
    ({bool move, bool verify}) after,
  ) async {
    final source = await rt.endpoints.resolve(job.source.hostId);
    final target = await rt.endpoints.resolve(job.target.hostId);
    final left = await source.stat(job.source.path);
    final right = await target.stat(job.target.path);
    if (left == null || right == null || (!left.isDirectory && left.size != right.size)) {
      throw ActionFailure('The copy of ${job.name} does not match. The original was kept');
    }
    if (after.verify && !left.isDirectory) {
      final digests = await Future.wait([
        _digest(rt, job.source.hostId!, job.source.path),
        _digest(rt, job.target.hostId!, job.target.path),
      ]);
      if (digests[0] == null || digests[0] != digests[1]) {
        throw ActionFailure('The checksum of ${job.name} does not match. The original was kept');
      }
    }
    if (after.move) await source.deleteFile(job.source.path);
  }

  static Future<String?> _digest(WarpgateRuntime rt, String hostId, String path) async {
    final quoted = "'${path.replaceAll("'", r"'\''")}'";
    final result = await rt.pool.exec(
      hostId,
      'if command -v sha256sum >/dev/null 2>&1; then sha256sum -- $quoted; else shasum -a 256 -- $quoted; fi',
      timeout: const Duration(minutes: 30),
    );
    return FileChecksum.parse(result.stdout);
  }
}
