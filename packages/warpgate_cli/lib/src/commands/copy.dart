import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/platform/native.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
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

abstract final class CopyCommands {
  static final Map<String, LocalCommand> all = {
    'files.cat': _cat,
    'files.get': _get,
    'files.put': _put,
    'files.cp': _cp,
    'files.edit': _edit,
    'transfers.watch': _watch,
    'transfers.resume': _resume,
    'transfers.retry': _retry,
  };

  static Future<JsonMap?> _cat(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    if (context.output.json) {
      return await ActionHandlers.all['files.cat']!(ActionCall(rt, args));
    }
    final ref = PathRef.parse(args['path']! as String);
    final (endpoint, path) = await _open(rt, ref);
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

  static Future<(FileEndpoint, String)> _open(WarpgateRuntime rt, PathRef ref) async {
    final hostId = ref.host == null ? null : rt.host(ref.host!).id;
    final endpoint = await rt.endpoints.resolve(hostId);
    return (endpoint, await endpoint.resolve(ref.path));
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
    final (endpoint, path) = await _open(rt, PathRef.parse(target));
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
    final (targetEndpoint, targetRoot) = await _open(rt, targetRef);
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
      final (endpoint, path) = await _open(rt, ref);
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
          origin: 'cli',
          move: move && !direct,
          verify: verify && !direct,
          ownerPid: pid,
          start: false,
        ),
      );
    }
    return await _runJobs(
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

  static Future<JsonMap?> _runJobs(
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
      ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
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
          controlPoll: const Duration(milliseconds: 500),
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

  static Future<JsonMap?> _edit(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    final text = args['path']! as String;
    final ref = PathRef.parse(text);
    if (!ref.isRemote) {
      throw ActionFailure('$text is a local path. Use host:path', kind: ExitKind.usage);
    }
    final (endpoint, path) = await _open(rt, ref);
    final environment = Platform.environment;
    final editor =
        environment['VISUAL'] ??
        environment['EDITOR'] ??
        (Platform.isWindows ? 'notepad' : 'vi');
    final before = await endpoint.stat(path);
    if (before != null && before.isDirectory) {
      throw ActionFailure('$text is a folder', kind: ExitKind.usage);
    }
    final temp = await Directory.systemTemp.createTemp('warpgate-edit-');
    Native.chmod(temp.path, 448);
    final local = File(p.join(temp.path, p.posix.basename(path)));
    final data = before == null ? Uint8List(0) : await endpoint.readAll(path, maxBytes: 64 * 1024 * 1024);
    await local.writeAsBytes(data, flush: true);
    Native.chmod(local.path, 384);
    var uploaded = false;
    var keep = false;
    var known = local.statSync().modified;
    var remoteStamp = before?.modified;
    var remoteSize = before?.size;

    Future<void> upload() async {
      final current = await endpoint.stat(path);
      final moved = current != null && (current.modified != remoteStamp || current.size != remoteSize);
      if (moved && !context.prompter.confirm('$text changed on the host while you edited. Replace it?')) {
        throw ActionFailure('Kept your edit at ${local.path}. The file on the host was not changed');
      }
      await endpoint.writeAll(path, await local.readAsBytes());
      final after = await endpoint.stat(path);
      remoteStamp = after?.modified;
      remoteSize = after?.size;
      uploaded = true;
      context.output.note('Uploaded $text');
    }

    var uploading = Future<void>.value();
    final watcher = Timer.periodic(const Duration(seconds: 1), (_) {
      final stamp = local.statSync().modified;
      if (stamp != known) {
        known = stamp;
        uploading = uploading.then((_) => upload());
      }
    });
    try {
      final words = editor.split(' ');
      final process = await Process.start(
        words.first,
        [...words.skip(1), local.path],
        mode: ProcessStartMode.inheritStdio,
      );
      final code = await process.exitCode;
      watcher.cancel();
      await uploading;
      if (code != 0) {
        keep = true;
        throw ActionFailure('$editor exited with code $code. Kept your edit at ${local.path}');
      }
      final stamp = local.statSync().modified;
      if (stamp != known) {
        known = stamp;
        await upload();
      }
      if (!uploaded) context.output.note('No changes');
    } on ProcessException {
      throw ActionFailure(
        'Could not start the editor "$editor"',
        hint: r'Set $EDITOR to one you have',
      );
    } on ActionFailure {
      keep = true;
      rethrow;
    } on Object {
      keep = true;
      context.output.raw('Kept your edit at ${local.path}\n');
      rethrow;
    } finally {
      watcher.cancel();
      if (!keep) await temp.delete(recursive: true);
    }
    return {'path': path, 'uploaded': uploaded};
  }

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
      await Future<void>.delayed(const Duration(milliseconds: 500));
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
    final queue = scheduler(rt, initial: jobs);
    return await _runJobs(
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
