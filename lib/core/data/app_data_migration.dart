import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class AppIdentity {
  static const bundleId = 'eu.kwilex.warpgate';
  static const legacyBundleId = 'dev.warpgate.app';
  static const String keychainGroup = bundleId;
  static const databaseName = 'warpgate';
  static const marker = '.migrated';
}

abstract final class AppDataMigration {
  static List<String> legacyFolders(String current) {
    final parent = p.dirname(current);
    if (Platform.isWindows) {
      final roaming = p.dirname(parent);
      return [p.join(roaming, 'Warpgate', 'warpgate')];
    }
    return [p.join(parent, AppIdentity.legacyBundleId)];
  }

  static Future<String?> run(String current, {List<String>? legacy}) async {
    final target = Directory(current);
    final database = File(
      p.join(current, '${AppIdentity.databaseName}.sqlite'),
    );
    if (database.existsSync()) return null;
    for (final candidate in legacy ?? legacyFolders(current)) {
      if (p.equals(candidate, current)) continue;
      final source = Directory(candidate);
      if (!source.existsSync()) continue;
      final hasData = source.listSync().any(
        (entity) => p.basename(entity.path) != AppIdentity.marker,
      );
      if (!hasData) continue;
      await target.create(recursive: true);
      await _copy(source, target);
      await File(p.join(current, AppIdentity.marker))
          .writeAsString(candidate, flush: true);
      return candidate;
    }
    return null;
  }

  static Future<void> _copy(Directory from, Directory to) async {
    await for (final entity in from.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final destination = p.join(to.path, name);
      if (entity is Directory) {
        final next = Directory(destination);
        await next.create(recursive: true);
        await _copy(entity, next);
      } else if (entity is File) {
        if (!File(destination).existsSync()) await entity.copy(destination);
      }
    }
  }
}
