import 'dart:convert';

import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/file_targets.dart';
import 'package:warpgate_core/actions/support/globs.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

abstract final class FileHandlers {
  static final Map<String, ActionHandler> all = {
    'files.ls': _ls,
    'files.cat': _cat,
    'files.mv': _mv,
    'files.rm': _rm,
    'files.mkdir': _mkdir,
    'files.chmod': _chmod,
    'files.stat': _stat,
    'files.find': _find,
    'files.du': _du,
  };

  static List<FileEntry> _sorted(List<FileEntry> entries, String sort) {
    final list = [...entries];
    switch (sort) {
      case 'size':
        list.sort((a, b) => b.size.compareTo(a.size));
      case 'time':
        list.sort(
          (a, b) => (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)),
        );
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  static Future<JsonMap> _ls(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    final showAll = call.on('all');
    final sort = call.maybe('sort') ?? 'name';
    final tree = call.on('tree');
    final rows = <JsonMap>[];
    Future<void> walk(String directory, int depth) async {
      final entries = await endpoint.list(directory);
      for (final entry in _sorted(entries, sort)) {
        if (!showAll && entry.isHidden) continue;
        rows.add({
          ...Json.entry(entry),
          if (tree) 'depth': depth,
        });
        if (tree && entry.isDirectory && !entry.isLink) {
          await walk(entry.path, depth + 1);
        }
      }
    }

    final root = await endpoint.stat(path);
    if (root == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    if (root.isDirectory) {
      await walk(path, 0);
    } else {
      rows.add(Json.entry(root));
    }
    return {'path': path, 'entries': rows};
  }

  static Future<JsonMap> _cat(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    final bytes = await endpoint.readAll(path, maxBytes: ActionLimits.maxReadBytes);
    return {
      'path': path,
      'size': bytes.length,
      'content': utf8.decode(bytes, allowMalformed: true),
    };
  }

  static Future<JsonMap> _mv(ActionCall call) async {
    final source = PathRef.parse(call.string('source'));
    final rawTarget = call.string('target');
    final parsed = PathRef.parse(rawTarget);
    final targetRef = parsed.isRemote ? parsed : PathRef(parsed.path, host: source.host);
    if (source.host != targetRef.host) {
      throw const ActionFailure(
        'mv works within one host',
        kind: ExitKind.usage,
        hint: 'Use warpgate cp --move to move between hosts',
      );
    }
    final (endpoint, from, _) = await FileTargets.open(call.runtime, source);
    var to = await endpoint.resolve(targetRef.path);
    final existing = await endpoint.stat(to);
    if (existing != null && existing.isDirectory) {
      to = endpoint.paths.join(to, endpoint.paths.basename(from));
    }
    await endpoint.rename(from, to);
    return {'source': from, 'target': to};
  }

  static Future<JsonMap> _rm(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    final entry = await endpoint.stat(path);
    if (entry == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    if (entry.isDirectory && !entry.isLink) {
      if (!call.on('recursive')) {
        throw ActionFailure(
          '$path is a folder',
          kind: ExitKind.usage,
          hint: 'Add -r to delete it and everything in it',
        );
      }
      await endpoint.deleteDirectory(path);
    } else {
      await endpoint.deleteFile(path);
    }
    return {'path': path};
  }

  static Future<JsonMap> _mkdir(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    if (call.on('parents')) {
      final missing = <String>[];
      var cursor = path;
      while (!await endpoint.exists(cursor)) {
        missing.add(cursor);
        final parent = endpoint.paths.dirname(cursor);
        if (parent == cursor) break;
        cursor = parent;
      }
      for (final folder in missing.reversed) {
        await endpoint.createDirectory(folder);
      }
    } else {
      await endpoint.createDirectory(path);
    }
    return {'path': path};
  }

  static Future<JsonMap> _chmod(ActionCall call) async {
    final raw = call.string('mode');
    final mode = int.tryParse(raw, radix: 8);
    if (mode == null || mode < 0 || mode > ActionLimits.maxMode) {
      throw ActionFailure('"$raw" is not an octal mode', kind: ExitKind.usage);
    }
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    await endpoint.setMode(path, mode);
    return {'path': path, 'mode': raw};
  }

  static Future<JsonMap> _stat(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    final entry = await endpoint.stat(path);
    if (entry == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    return {'entry': Json.entry(entry)};
  }

  static Future<JsonMap> _find(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    final pattern = Globs.compile(call.string('pattern'));
    final limit = int.tryParse(call.maybe('max') ?? '') ?? ActionLimits.findMatches;
    final matches = <JsonMap>[];
    var truncated = false;
    Future<void> walk(String directory) async {
      for (final entry in await endpoint.list(directory)) {
        if (matches.length >= limit) {
          truncated = true;
          return;
        }
        if (pattern.hasMatch(entry.name)) matches.add(Json.entry(entry));
        if (entry.isDirectory && !entry.isLink) {
          try {
            await walk(entry.path);
          } on FileOperationException {
            continue;
          }
        }
      }
    }

    await walk(path);
    return {'matches': matches, 'truncated': truncated};
  }

  static Future<JsonMap> _du(ActionCall call) async {
    final (endpoint, path, _) = await FileTargets.endpoint(call, 'path');
    var files = 0;
    Future<int> measure(FileEntry entry) async {
      if (entry.isLink) return 0;
      if (!entry.isDirectory) {
        files += 1;
        return entry.size;
      }
      var sum = 0;
      try {
        for (final child in await endpoint.list(entry.path)) {
          sum += await measure(child);
        }
      } on FileOperationException {
        return sum;
      }
      return sum;
    }

    final root = await endpoint.stat(path);
    if (root == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    final children = <JsonMap>[];
    var total = 0;
    if (root.isDirectory) {
      for (final child in await endpoint.list(path)) {
        final size = await measure(child);
        total += size;
        children.add({'name': child.name, 'size': size});
      }
      children.sort((a, b) => (b['size']! as int).compareTo(a['size']! as int));
    } else {
      total = root.size;
      files = 1;
    }
    return {'path': path, 'total': total, 'files': files, 'children': children};
  }
}
