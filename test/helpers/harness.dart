import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/app/app.dart';
import 'package:warpgate/app/router.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate_core/core/data/secret_store.dart';

Widget themed(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WgTheme.build(brightness: brightness),
      home: Scaffold(body: child),
    );

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  List<Object> extra = const [],
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      routerProvider.overrideWithValue(buildRouter()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const WarpgateApp()),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

extension Settle on WidgetTester {
  Future<void> settleFor([
    Duration duration = const Duration(milliseconds: 600),
  ]) async {
    for (
      var elapsed = Duration.zero;
      elapsed < duration;
      elapsed += const Duration(milliseconds: 50)
    ) {
      await pump(const Duration(milliseconds: 50));
    }
  }
}
