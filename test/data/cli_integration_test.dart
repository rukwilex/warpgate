import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

void main() {
  test('the palette is built from the registry, nothing else', () {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        initialSettingsProvider.overrideWithValue(const AppSettings(appLock: true)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
    final commands = container.read(commandRegistryProvider).commands();
    final built = commands.map((command) => command.id).toSet();
    final declared = ActionRegistry.paletteEntries.map((entry) => entry.id).toSet();
    final conditional = {
      'session.local',
      for (var i = 2; i <= 9; i++) 'workspace.$i',
    };
    expect(built.difference(declared), isEmpty);
    final unbuilt = declared.difference(built).difference(conditional);
    expect(unbuilt, isEmpty);
    for (final command in commands.where((command) => !command.id.startsWith('workspace.'))) {
      final entry = ActionRegistry.paletteEntries.firstWhere((item) => item.id == command.id);
      expect(command.title, entry.title);
      expect(command.category, entry.category);
    }
  });

  test('the app and the CLI share one database file safely', () async {
    final root = Directory.systemTemp.createTempSync('wg');
    addTearDown(() => root.deleteSync(recursive: true));
    final path = p.join(root.path, 'warpgate.sqlite');
    final database = AppDatabase(NativeDatabase(File(path)));
    final app = DriftDocumentStore(database);
    await app.put('hosts', 'from-app', {'id': 'from-app'});
    final cli = SqliteDocumentStore.open(path);
    expect(await cli.get('hosts', 'from-app'), isNotNull);
    final before = await app.dataVersion();
    await cli.put('hosts', 'from-cli', {'id': 'from-cli'});
    expect(await app.dataVersion(), isNot(before));
    expect(await app.get('hosts', 'from-cli'), isNotNull);
    await Future.wait([
      for (var i = 0; i < 40; i++)
        if (i.isEven)
          app.put('hosts', 'a$i', {'id': 'a$i'})
        else
          cli.put('hosts', 'c$i', {'id': 'c$i'}),
    ]);
    expect(await app.all('hosts'), hasLength(42));
    cli.close();
    await database.close();
  });
}
