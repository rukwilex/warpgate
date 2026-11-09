import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/copy.dart';
import 'package:warpgate_cli/src/commands/transfer_runner.dart';
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

abstract final class TransferCommands {
  static final Map<String, LocalCommand> all = {
    'transfers.watch': _watch,
    'transfers.resume': _resume,
    'transfers.retry': _retry,
  };

  static Future<JsonMap?> _watch(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    final output = context.output;
    final filter = args['id'] as String?;
    var printed = 0;
    while (true) {
      final jobs = (await TransferScheduler.load(rt.store))
          .where((job) => filter == null || job.id.startsWith(filter))
          .toList();
      final active = jobs.where((job) => job.status.isActive).toList();
      if (output.showProgress) {
        if (printed > 0) output.raw('\x1B[${printed}A');
        for (final job in active) {
          output.raw('\r\x1B[2K${Progress.bar(job, 30)}\n');
        }
        for (var i = active.length; i < printed; i++) {
          output.raw('\r\x1B[2K\n');
        }
        if (printed > active.length) output.raw('\x1B[${printed - active.length}A');
        printed = active.length;
      }
      if (active.isEmpty) {
        return {
          'transfers': [for (final job in jobs) Json.transfer(rt, job)],
        };
      }
      await Future<void>.delayed(ActionTimeouts.transferPoll);
    }
  }

  static Future<JsonMap?> _foreground(
    CliContext context,
    ActionSpec action,
    WarpgateRuntime rt,
    List<TransferJob> jobs,
    List<String> ids,
  ) async {
    final settings = await rt.settings.load();
    final queue = CopyCommands.scheduler(rt, initial: jobs);
    return await TransferRunner.run(
      context,
      action,
      rt,
      queue,
      ids,
      policy: context.prompter.interactive ? settings.conflictPolicy : ConflictPolicy.overwrite,
    );
  }

  static Future<JsonMap?> _resume(CliContext context, ActionSpec action, JsonMap args) async {
    final client = await context.client();
    if (client != null) {
      return await client.call('action', {'name': action.name, 'args': args});
    }
    final rt = await context.runtime();
    final job = await ActionHandlers.findJob(rt, args['id']! as String);
    return await _foreground(context, action, rt, await TransferScheduler.load(rt.store), [job.id]);
  }

  static Future<JsonMap?> _retry(CliContext context, ActionSpec action, JsonMap args) async {
    final client = await context.client();
    if (client != null) {
      return await client.call('action', {'name': action.name, 'args': args});
    }
    final rt = await context.runtime();
    final all = await TransferScheduler.load(rt.store);
    final reference = args['id']! as String;
    final ids = reference == 'failed'
        ? [
            for (final job in all)
              if (job.status == TransferStatus.failed) job.id,
          ]
        : [(await ActionHandlers.findJob(rt, reference)).id];
    if (ids.isEmpty) {
      context.output.note('Nothing to retry');
      return {'transfers': const <Object?>[], 'failed': 0};
    }
    return await _foreground(context, action, rt, all, ids);
  }
}
