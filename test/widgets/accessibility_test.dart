import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';

import '../helpers/harness.dart';
import '../screens/render_screens_test.dart' show seedHosts;

void main() {
  for (final route in [
    Routes.workbench,
    Routes.hosts,
    Routes.transfers,
    Routes.multiExec,
    Routes.settings,
    Routes.keys,
  ]) {
    testWidgets('a11y guidelines on $route', (tester) async {
      final handle = tester.ensureSemantics();
      final container = await pumpApp(tester);
      await seedHosts(container);
      container.read(routerProvider).go(route);
      await tester.settleFor();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('phone tap targets are at least 44', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(tester, size: const Size(390, 844));
    await seedHosts(container);
    container.read(routerProvider).go(Routes.hosts);
    await tester.settleFor();
    await expectLater(
      tester,
      meetsGuideline(
        const MinimumTapTargetGuideline(
          size: Size(44, 44),
          link: 'https://www.w3.org/WAI/WCAG21/Understanding/target-size.html',
        ),
      ),
    );
    handle.dispose();
  });

  for (final route in [
    Routes.workbench,
    Routes.hosts,
    Routes.settings,
    Routes.transfers,
  ]) {
    testWidgets('200% text does not overflow on $route', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await pumpApp(tester);
      await seedHosts(container);
      container.read(routerProvider).go(route);
      await tester.settleFor();
      expect(tester.takeException(), isNull);
    });
  }
}
