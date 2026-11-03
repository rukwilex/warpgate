import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate_core/core/data/app_data_migration.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('wg-migrate'));
  tearDown(() => root.deleteSync(recursive: true));

  test('copies the old folder when the new one has no database', () async {
    final old = Directory(p.join(root.path, AppIdentity.legacyBundleId))
      ..createSync();
    File(p.join(old.path, 'warpgate.sqlite')).writeAsStringSync('db');
    Directory(p.join(old.path, 'logs')).createSync();
    File(p.join(old.path, 'logs', 'a.txt')).writeAsStringSync('log');
    final current = p.join(root.path, AppIdentity.bundleId);
    final from = await AppDataMigration.run(current, legacy: [old.path]);
    expect(from, old.path);
    expect(File(p.join(current, 'warpgate.sqlite')).readAsStringSync(), 'db');
    expect(File(p.join(current, 'logs', 'a.txt')).readAsStringSync(), 'log');
    expect(old.existsSync(), isTrue);
  });

  test('leaves an existing database alone', () async {
    final old = Directory(p.join(root.path, 'old'))..createSync();
    File(p.join(old.path, 'warpgate.sqlite')).writeAsStringSync('old');
    final current = Directory(p.join(root.path, 'new'))..createSync();
    File(p.join(current.path, 'warpgate.sqlite')).writeAsStringSync('new');
    final from = await AppDataMigration.run(current.path, legacy: [old.path]);
    expect(from, isNull);
    expect(
      File(p.join(current.path, 'warpgate.sqlite')).readAsStringSync(),
      'new',
    );
  });

  test('does nothing on a clean install', () async {
    final current = p.join(root.path, 'new');
    final from = await AppDataMigration.run(
      current,
      legacy: [p.join(root.path, 'missing')],
    );
    expect(from, isNull);
    expect(Directory(current).existsSync(), isFalse);
  });

  test('legacy folder sits next to the new one', () {
    final legacy = AppDataMigration.legacyFolders(
      p.join('/home/me/.local/share', AppIdentity.bundleId),
    );
    if (!Platform.isWindows) {
      expect(
        legacy.single,
        '/home/me/.local/share/${AppIdentity.legacyBundleId}',
      );
    }
  });
}
