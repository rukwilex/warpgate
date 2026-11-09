import 'dart:io';
import 'dart:typed_data';

import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/edit.dart';
import 'package:warpgate_cli/src/commands/transfer_runner.dart';
import 'package:warpgate_cli/src/commands/transfers.dart';
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/support/file_targets.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/platform/native.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

abstract final class CopyCommands {
  static final Map<String, LocalCommand> all = {
    'files.cat': _cat,
    'files.get': _get,
    'files.put': _put,
    'files.cp': _cp,
    'files.edit': EditCommand.run,
    ...TransferCommands.all,
  };

  static Future<JsonMap?> _cat(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    if (context.output.json) {
      return await ActionHandlers.all['files.cat']!(ActionCall(rt, args));
    }
    final ref = PathRef.parse(args['path']! as String);
    final (endpoint, path, _) = await FileTargets.open(rt, ref);
    final entry = await endpoint.stat(path);
    if (entry == null) {
      throw ActionFailure('$ref does not exist', kind: ExitKind.notFound);
    }
    if (entry.isDirectory) {
      throw ActionFailure('$ref is a folder', hint: 'Use warpgate ls to list it');
    }
    await endpoint.read(path).forEach(stdout.add);
    return null;
  }

  static Future<JsonMap?> _get(CliContext context, ActionSpec action, JsonMap args) {
    final source = args['source']! as String;
    if (!PathRef.parse(source).isRemote) {
      throw ActionFailure(
        '$source is a local path',
        kind: ExitKind.usage,
        hint: 'Use host:path, or warpgate cp to copy between local paths',
      );
    }
    return runCopy(context, action, [source], (args['target'] as String?) ?? './', args);
  }

  static Future<JsonMap?> _put(CliContext context, ActionSpec action, JsonMap args) async {
    final source = args['source']! as String;
    final target = args['target']! as String;
    if (!PathRef.parse(target).isRemote) {
      throw ActionFailure(
        '$target is a local path',
        kind: ExitKind.usage,
        hint: 'Use host:path',
      );
    }
    if (source == '-') return await _putStdin(context, action, target);
    return await runCopy(context, action, [source], target, args);
  }

  static Future<JsonMap?> _putStdin(CliContext context, ActionSpec action, String target) async {
    final rt = await context.runtime();
    final (endpoint, path, _) = await FileTargets.open(rt, PathRef.parse(target));
    final existing = await endpoint.stat(path);
    if (existing != null && existing.isDirectory) {
      throw ActionFailure('$target is a folder. Name a file to write to', kind: ExitKind.usage);
    }
    await endpoint.write(path, stdin.map(Uint8List.fromList));
    return {'transfers': const <Object?>[], 'failed': 0};
  }

  static Future<JsonMap?> _cp(CliContext context, ActionSpec action, JsonMap args) async {
    final paths = (args['source']! as List).cast<String>();
    if (paths.length < 2) {
      throw const ActionFailure(
        'Name a source and a target',
        kind: ExitKind.usage,
        hint: 'warpgate cp prod:/var/log/app.log staging:/tmp/',
      );
    }
    return await runCopy(context, action, paths.sublist(0, paths.length - 1), paths.last, args);
  }

  static TransferRef _ref(String? hostId, String path) => TransferRef(hostId: hostId, path: path);

  static TransferScheduler scheduler(WarpgateRuntime rt, {List<TransferJob> initial = const []}) =>
      TransferScheduler(
        store: rt.store,
        pool: rt.pool,
        resolver: rt.endpoints,
        broker: rt.broker,
        hostOf: (id) => id == null ? null : rt.lookup(id),
        settings: () => const AppSettings(),
        autoRun: false,
        isAlive: Native.isProcessAlive,
        initial: initial,
      );

  static Future<JsonMap?> runCopy(
    CliContext context,
    ActionSpec action,
    List<String> sources,
    String targetText,
    JsonMap args,
  ) async {
    if (args['queue'] == true) {
      final client = await context.requireApp(action);
      return await client.call('action', {
        'name': 'files.cp',
        'args': {...args, 'sources': sources, 'target': targetText},
      });
    }
    final rt = await context.runtime();
    final settings = await rt.settings.load();
    final conflict = args['on-conflict'] as String?;
    final policy = switch (conflict) {
      'overwrite' => ConflictPolicy.overwrite,
      'skip' => ConflictPolicy.skip,
      'rename' => ConflictPolicy.rename,
      'ask' => ConflictPolicy.ask,
      _ => context.prompter.interactive ? settings.conflictPolicy : ConflictPolicy.overwrite,
    };
    final recursive = args['recursive'] == true;
    final move = args['move'] == true;
    final direct = args['direct'] == true;
    final verify = args['verify'] == true;
    final resume = args['resume'] == true;
    final targetRef = PathRef.parse(targetText);
    final (targetEndpoint, targetRoot, _) = await FileTargets.open(rt, targetRef);
    final targetEntry = await targetEndpoint.stat(targetRoot);
    final targetIsFolder =
        targetEntry?.isDirectory == true ||
        targetText.endsWith('/') ||
        targetText.endsWith(Platform.pathSeparator);
    if (sources.length > 1 && !targetIsFolder) {
      throw ActionFailure(
        'With several sources the target must be a folder: $targetText',
        kind: ExitKind.usage,
      );
    }
    if (targetIsFolder && targetEntry == null) {
      throw ActionFailure(
        '$targetText does not exist',
        kind: ExitKind.notFound,
        hint: 'Create it first with warpgate mkdir -p',
      );
    }
    final queue = scheduler(rt);
    final targetHostId = targetRef.host == null ? null : rt.host(targetRef.host!).id;
    final ids = <String>[];
    for (final text in sources) {
      final ref = PathRef.parse(text);
      final (endpoint, path, _) = await FileTargets.open(rt, ref);
      final entry = await endpoint.stat(path);
      if (entry == null) {
        throw ActionFailure('$text does not exist', kind: ExitKind.notFound);
      }
      if (entry.isDirectory && !recursive) {
        throw ActionFailure(
          '$text is a folder',
          kind: ExitKind.usage,
          hint: 'Add -r to copy it and everything in it',
        );
      }
      final hostId = ref.host == null ? null : rt.host(ref.host!).id;
      final name = endpoint.paths.basename(path);
      final destination = targetIsFolder ? targetEndpoint.paths.join(targetRoot, name) : targetRoot;
      if (direct) {
        if (hostId == null || targetHostId == null) {
          throw const ActionFailure('--direct works between two hosts', kind: ExitKind.usage);
        }
        if (move && entry.isDirectory) {
          throw const ActionFailure(
            '--direct --move works on one file',
            kind: ExitKind.usage,
            hint: 'Leave out --direct to move a folder with a check on each file',
          );
        }
      }
      ids.add(
        queue.enqueue(
          source: _ref(hostId, path),
          target: _ref(targetHostId, destination),
          name: name,
          isDirectory: entry.isDirectory,
          mode: direct ? TransferMode.direct : TransferMode.stream,
          origin: ActionOrigins.cli,
          move: move && !direct,
          verify: verify && !direct,
          ownerPid: pid,
          start: false,
        ),
      );
    }
    return await TransferRunner.run(
      context,
      action,
      rt,
      queue,
      ids,
      policy: policy,
      forced: resume ? ConflictResolution.resume : null,
      afterDirect: direct ? (move: move, verify: verify) : null,
    );
  }
}
