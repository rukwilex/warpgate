import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_core/core/data/app_data_migration.dart';

class AppPaths {
  const new(this.root, {this.profile, this.runtimeDirectories = const []});

  factory resolve({
    String? profile,
    Map<String, String>? environment,
    String? platformRoot,
  }) {
    final env = environment ?? Platform.environment;
    final chosen = profile ?? env['WARPGATE_PROFILE'];
    final base = env['WARPGATE_HOME'] ?? platformRoot ?? defaultRoot(env);
    return AppPaths(
      chosen == null || chosen.isEmpty ? base : p.join(base, 'profiles', chosen),
      profile: chosen == null || chosen.isEmpty ? null : chosen,
      runtimeDirectories: [?env['XDG_RUNTIME_DIR'], ?env['TMPDIR']],
    );
  }

  final String root;
  final String? profile;
  final List<String> runtimeDirectories;

  static const maxSocketPath = 100;

  static String _fnv(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static String defaultRoot(Map<String, String> env) {
    if (Platform.isMacOS) {
      return p.join(
        env['HOME'] ?? '',
        'Library',
        'Application Support',
        AppIdentity.bundleId,
      );
    }
    if (Platform.isWindows) {
      return p.join(env['APPDATA'] ?? '', 'eu.kwilex', 'Warpgate');
    }
    final data = env['XDG_DATA_HOME'] ?? p.join(env['HOME'] ?? '', '.local', 'share');
    return p.join(data, AppIdentity.bundleId);
  }

  String get database => p.join(root, '${AppIdentity.databaseName}.sqlite');

  String get ipcDirectory => p.join(root, 'ipc');

  String get ipcSocket {
    final primary = p.join(ipcDirectory, 'warpgate.sock');
    if (primary.length <= maxSocketPath) return primary;
    for (final directory in runtimeDirectories) {
      final candidate = p.join(directory, 'wg-${_fnv(root)}.sock');
      if (candidate.length <= maxSocketPath) return candidate;
    }
    return primary;
  }

  String get ipcLock => p.join(ipcDirectory, 'app.lock');

  String get ipcToken => p.join(ipcDirectory, 'token');

  String get ipcPort => p.join(ipcDirectory, 'port');

  String get cache => p.join(root, 'cache');

  String get keychainAccount => profile == null
      ? 'warpgate.master-key'
      : 'warpgate.master-key.$profile';
}
