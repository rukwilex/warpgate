import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

abstract final class InstallCommands {
  static final Map<String, LocalCommand> all = {
    'install': _install,
    'uninstall': _uninstall,
  };

  static String? _installTarget() {
    final environment = Platform.environment;
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    if (home == null) return null;
    return p.join(home, '.local', 'bin', 'warpgate');
  }

  static bool _isWritable(String directory) {
    if (!Directory(directory).existsSync()) return false;
    final probe = File(p.join(directory, '.warpgate-$pid'));
    try {
      probe
        ..writeAsStringSync('')
        ..deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static bool onPath(String directory) {
    final separator = Platform.isWindows ? ';' : ':';
    return (Platform.environment['PATH'] ?? '')
        .split(separator)
        .any((item) => p.equals(item, directory));
  }

  static String get _windowsBin => p.join(
    Platform.environment['LOCALAPPDATA'] ?? '',
    'Warpgate',
    'bin',
  );

  static List<String> installPlaces() {
    final override = Platform.environment['WARPGATE_INSTALL_DIR'];
    if (override != null) return [p.join(override, 'warpgate')];
    return Platform.isWindows
        ? [p.join(_windowsBin, 'warpgate.cmd')]
        : ['/usr/local/bin/warpgate', ?_installTarget()];
  }

  static Future<JsonMap?> _install(CliContext context, ActionSpec action, JsonMap args) async {
    final executable = Platform.resolvedExecutable;
    if (Platform.isWindows && !Platform.environment.containsKey('WARPGATE_INSTALL_DIR')) {
      final directory = Directory(_windowsBin);
      await directory.create(recursive: true);
      final shim = File(p.join(directory.path, 'warpgate.cmd'));
      await shim.writeAsString('@echo off\r\n"$executable" %*\r\n', flush: true);
      final script =
          r"$p=[Environment]::GetEnvironmentVariable('Path','User');"
          "\$d='${directory.path}';"
          r"if(($p -split ';') -notcontains $d){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$d).TrimStart(';'),'User')}";
      final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      if (result.exitCode != 0) {
        throw ActionFailure('Could not change your PATH: ${result.stderr}');
      }
      return {'path': shim.path, 'needs_new_shell': true};
    }
    final places = installPlaces();
    final chosen = _isWritable(p.dirname(places.first)) ? places.first : places.last;
    final directory = Directory(p.dirname(chosen));
    await directory.create(recursive: true);
    final link = Link(chosen);
    if (link.existsSync()) {
      await link.delete();
    } else if (File(chosen).existsSync()) {
      throw ActionFailure('$chosen already exists and is not a link. Remove it first');
    }
    await link.create(executable);
    if (!onPath(directory.path)) {
      context.output.note('Add ${directory.path} to your PATH to run warpgate from any folder.');
    }
    return {'path': chosen, 'needs_new_shell': !onPath(directory.path)};
  }

  static Future<JsonMap?> _uninstall(CliContext context, ActionSpec action, JsonMap args) async {
    var removed = false;
    for (final place in installPlaces()) {
      final link = Link(place);
      if (Platform.isWindows && File(place).existsSync()) {
        await File(place).delete();
        removed = true;
      } else if (link.existsSync()) {
        await link.delete();
        removed = true;
      }
    }
    return {'removed': removed};
  }
}
