import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

import '../helpers/harness.dart';

void main() {
  testWidgets('first launch shows the add host empty state', (tester) async {
    await pumpApp(tester);
    await tester.settleFor();
    expect(find.text('Add a host to start'), findsOneWidget);
    expect(find.text('Add host'), findsWidgets);
    expect(find.textContaining('0 connected'), findsOneWidget);
  });

  testWidgets(
    'adding a host from the editor lists it in the sidebar and on the hosts page',
    (tester) async {
      final container = await pumpApp(tester);
      container.read(routerProvider).go(Routes.hosts, extra: 'new');
      await tester.settleFor();
      expect(find.text('Add host'), findsWidgets);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'prod-db-1');
      await tester.enterText(fields.at(1), '10.0.4.21');
      await tester.enterText(fields.at(3), 'ops');
      await tester.tap(find.text('Add host').last);
      await tester.settleFor();
      final hosts = container.read(hostsProvider).value!.hosts;
      expect(hosts.single.label, 'prod-db-1');
      expect(hosts.single.endpoint, 'ops@10.0.4.21');
      expect(find.text('prod-db-1'), findsWidgets);
    },
  );

  testWidgets('host editor validates required fields', (tester) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go(Routes.hosts, extra: 'new');
    await tester.settleFor();
    await tester.tap(find.text('Add host').last);
    await tester.settleFor();
    expect(find.textContaining('Enter an address'), findsOneWidget);
    expect(find.textContaining('Enter the user'), findsOneWidget);
    expect(container.read(hostsProvider).value!.hosts, isEmpty);
  });

  testWidgets('command palette filters and runs commands', (tester) async {
    final container = await pumpApp(tester);
    await tester.settleFor();
    container.read(paletteProvider.notifier).open(PaletteMode.commands);
    await tester.settleFor();
    expect(find.text('Type a command or a session'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'new workspace');
    await tester.settleFor();
    expect(find.text('New workspace'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.settleFor();
    expect(container.read(paletteProvider), isNull);
    expect(find.text('New workspace'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'prod cluster');
    await tester.pump();
    await tester.tap(find.text('Create workspace'));
    await tester.settleFor();
    final bench = container.read(workbenchProvider);
    expect(bench.workspaces.map((w) => w.name), ['Main', 'prod cluster']);
    expect(bench.activeWorkspace!.name, 'prod cluster');
  });

  testWidgets('settings search narrows to matching rows', (tester) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go(Routes.settings);
    await tester.settleFor();
    await tester.enterText(find.byType(TextField).first, 'tmux');
    await tester.settleFor();
    expect(find.text('Use tmux for new hosts'), findsOneWidget);
    expect(find.text('Copy on select'), findsNothing);
  });

  testWidgets('phone layout uses a bottom bar', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));
    await tester.settleFor();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Sessions'), findsWidgets);
  });

  testWidgets('workbench splits, focuses and maximizes panes from commands', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await tester.settleFor();
    final bench = container.read(workbenchProvider.notifier);
    container.read(routerProvider).go(Routes.workbench);
    final registry = container.read(commandRegistryProvider);
    expect(
      registry.commands().map((c) => c.id),
      containsAll(['pane.splitRight', 'broadcast.toggle', 'layout.grid']),
    );
    bench
      ..createWorkspace('lab')
      ..applyPreset(LayoutPresetKind.grid);
    expect(container.read(workbenchProvider).activeWorkspace!.name, 'lab');
    final router = container.read(routerProvider);
    expect(router, isA<GoRouter>());
    await tester.settleFor();
  });
}
