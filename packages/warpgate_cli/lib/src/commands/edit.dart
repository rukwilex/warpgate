import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/editor.dart';
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/support/file_targets.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/platform/native.dart';

abstract final class EditCommand {
  static Future<JsonMap?> run(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    final text = args['path']! as String;
    final ref = PathRef.parse(text);
    if (!ref.isRemote) {
      throw ActionFailure('$text is a local path. Use host:path', kind: ExitKind.usage);
    }
    final (endpoint, path, _) = await FileTargets.open(rt, ref);
    final editor = Editors.command();
    final before = await endpoint.stat(path);
    if (before != null && before.isDirectory) {
      throw ActionFailure('$text is a folder', kind: ExitKind.usage);
    }
    final temp = await Directory.systemTemp.createTemp('warpgate-edit-');
    Native.chmod(temp.path, 448);
    final local = File(p.join(temp.path, p.posix.basename(path)));
    final data = before == null ? Uint8List(0) : await endpoint.readAll(path, maxBytes: ActionLimits.maxReadBytes);
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
}
