import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/title_bar.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

import '../helpers/harness.dart';

class _FakeControls implements WindowControls {
  final calls = <String>[];

  @override
  Future<void> startDragging() async => calls.add('drag');

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('toggleMaximize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> showSystemMenu() async => calls.add('systemMenu');

  @override
  Future<void> titleBarDoubleClick(WindowChrome chrome) async =>
      calls.add('doubleClick:${chrome.name}');

  @override
  Future<void> matchTheme(
    WindowChrome chrome, {
    required Color background,
    required Brightness brightness,
    required double titleBarHeight,
  }) async => calls.add('theme:$titleBarHeight');
}

class _FixedFrame extends WindowFrameController {
  new(this.frame);

  final WindowFrame frame;

  @override
  WindowFrame build() => frame;
}

const _size = Size(1440, 900);

Future<(ProviderContainer, _FakeControls)> _pump(
  WidgetTester tester,
  WindowChrome chrome, {
  WindowFrame frame = const WindowFrame(),
}) async {
  final controls = _FakeControls();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (_) async => null,
  );
  final container = await pumpApp(
    tester,
    overrides: [
      windowChromeProvider.overrideWithValue(chrome),
      windowFrameProvider.overrideWith(() => _FixedFrame(frame)),
      windowControlsProvider.overrideWithValue(controls),
    ],
  );
  await tester.settleFor();
  return (container, controls);
}

Finder get _titleBar => find.byKey(const ValueKey('title-bar'));

Finder get _inset => find.byKey(const ValueKey('title-bar-inset'));

Finder _semantics(String label) => find.bySemanticsLabel(label);

WgSizes _sizes(WidgetTester tester) =>
    Theme.of(tester.element(_titleBar)).extension<WgSizes>()!;

void main() {
  testWidgets('macOS reserves the traffic light inset', (tester) async {
    final (_, controls) = await _pump(tester, WindowChrome.mac);
    final sizes = _sizes(tester);
    final bar = tester.getRect(_titleBar);
    expect(bar.top, 0);
    expect(bar.width, _size.width);
    expect(bar.height, sizes.titleBar);
    expect(tester.getSize(_inset).width, sizes.trafficLights);
    final switcher = tester.getRect(find.text('Main'));
    expect(switcher.left, greaterThan(sizes.trafficLights));
    expect(switcher.center.dy, closeTo(bar.center.dy, 1));
    expect(_semantics('Minimize'), findsNothing);
    expect(_semantics('Close'), findsNothing);
    expect(find.text('Main'), findsOneWidget);
    expect(controls.calls, contains('theme:${sizes.titleBar}'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS full screen drops the inset', (tester) async {
    await _pump(
      tester,
      WindowChrome.mac,
      frame: const WindowFrame(fullScreen: true),
    );
    final sizes = _sizes(tester);
    final context = tester.element(_titleBar);
    expect(tester.getSize(_inset).width, context.space.sm);
    expect(
      tester.getRect(find.text('Main')).left,
      lessThan(sizes.trafficLights),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Windows draws caption buttons at the top right', (tester) async {
    final (_, controls) = await _pump(tester, WindowChrome.windows);
    final sizes = _sizes(tester);
    expect(tester.getSize(_inset).width, isNot(sizes.trafficLights));
    final minimize = tester.getRect(_semantics('Minimize'));
    final maximize = tester.getRect(_semantics('Maximize'));
    final close = tester.getRect(_semantics('Close'));
    for (final rect in [minimize, maximize, close]) {
      expect(rect.size, Size(sizes.captionButton, sizes.titleBar));
      expect(rect.top, 0);
    }
    expect(close.right, _size.width);
    expect(maximize.right, close.left);
    expect(minimize.right, maximize.left);
    final palette = tester.getRect(_semantics('Command palette'));
    expect(palette.right, lessThanOrEqualTo(minimize.left));
    expect(_semantics('Restore'), findsNothing);

    await tester.tap(_semantics('Minimize'));
    await tester.tap(_semantics('Maximize'));
    await tester.tap(_semantics('Close'));
    expect(
      controls.calls,
      containsAllInOrder(['minimize', 'toggleMaximize', 'close']),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows maximized shows the restore glyph', (tester) async {
    final (_, controls) = await _pump(
      tester,
      WindowChrome.windows,
      frame: const WindowFrame(maximized: true),
    );
    expect(_semantics('Maximize'), findsNothing);
    await tester.tap(_semantics('Restore'));
    expect(controls.calls, contains('toggleMaximize'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows caption buttons stay above dialogs', (tester) async {
    final (_, controls) = await _pump(tester, WindowChrome.windows);
    showDialog<void>(
      context: rootNavigatorKey.currentContext!,
      builder: (_) => const WgDialog(title: 'Test', child: SizedBox()),
    ).ignore();
    await tester.settleFor();
    await tester.tap(_semantics('Minimize'));
    expect(controls.calls, contains('minimize'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('empty bar drags, double-clicks and opens the system menu', (
    tester,
  ) async {
    final (_, controls) = await _pump(tester, WindowChrome.windows);
    final bar = tester.getRect(_titleBar);
    final empty = Offset(bar.center.dx, bar.center.dy);

    await tester.timedDragFrom(
      empty,
      const Offset(120, 40),
      const Duration(milliseconds: 200),
    );
    expect(controls.calls, contains('drag'));

    await tester.tapAt(empty);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(empty);
    await tester.settleFor();
    expect(controls.calls, contains('doubleClick:windows'));

    await tester.tapAt(empty, buttons: kSecondaryMouseButton);
    await tester.settleFor();
    expect(controls.calls, contains('systemMenu'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('tabs in the bar keep their own clicks', (tester) async {
    final (container, controls) = await _pump(tester, WindowChrome.mac);
    container.read(routerProvider).go(Routes.hosts);
    await tester.settleFor();
    final bench = container.read(workbenchProvider.notifier)
      ..openPane(const SshTerminalContent(hostId: 'alpha'))
      ..openPane(const SshTerminalContent(hostId: 'beta'));
    await tester.settleFor();
    expect(find.byType(WgTabChip), findsNWidgets(2));
    final chips = find.descendant(
      of: _titleBar,
      matching: find.byType(WgTabChip),
    );
    expect(chips, findsNWidgets(2));

    await tester.tap(chips.first);
    await tester.settleFor();
    expect(controls.calls, isNot(contains('drag')));
    expect(controls.calls.where((c) => c.startsWith('doubleClick')), isEmpty);
    final state = container.read(workbenchProvider);
    expect(state.activeTab?.id, state.activeWorkspace!.tabs.first.id);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.workbench,
    );

    await tester.tap(chips.first, buttons: kSecondaryMouseButton);
    await tester.settleFor();
    expect(find.text('Rename tab'), findsOneWidget);
    expect(controls.calls, isNot(contains('systemMenu')));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    for (final tab in [
      ...container.read(workbenchProvider).activeWorkspace!.tabs,
    ]) {
      bench.closeTab(tab.id);
    }
    await tester.settleFor(const Duration(seconds: 3));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('inactive window mutes the bar', (tester) async {
    await _pump(
      tester,
      WindowChrome.mac,
      frame: const WindowFrame(focused: false),
    );
    final colors = Theme.of(tester.element(_titleBar)).extension<WgColors>()!;
    final label = tester.widget<Text>(find.text('Main'));
    expect(label.style?.color, colors.textMuted);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('compact density uses the shorter bar', (tester) async {
    final (container, controls) = await _pump(tester, WindowChrome.windows);
    container.read(settingsProvider.notifier).update({'density': 'compact'});
    await tester.settleFor();
    final sizes = _sizes(tester);
    expect(
      sizes.titleBar,
      lessThan(const WgSizes(row: 0, control: 0).titleBar),
    );
    expect(tester.getSize(_titleBar).height, sizes.titleBar);
    expect(tester.getSize(_semantics('Close')).height, sizes.titleBar);
    expect(controls.calls, contains('theme:${sizes.titleBar}'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Linux and other platforms keep the native frame', (
    tester,
  ) async {
    await _pump(tester, WindowChrome.native);
    expect(_titleBar, findsNothing);
    expect(find.byType(WindowCaptionButtons), findsNothing);
    expect(find.text('Main'), findsOneWidget);
    expect(_semantics('Command palette'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final (chrome, platform) in [
    (WindowChrome.mac, TargetPlatform.macOS),
    (WindowChrome.windows, TargetPlatform.windows),
  ]) {
    for (final focused in [true, false]) {
      testWidgets(
        '${chrome.name} title bar is labeled and readable, focused $focused',
        variant: TargetPlatformVariant.only(platform),
        (tester) async {
          final handle = tester.ensureSemantics();
          await _pump(tester, chrome, frame: WindowFrame(focused: focused));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(find.bySemanticsLabel('Title bar'), findsOneWidget);
          handle.dispose();
        },
      );
    }
  }

  testWidgets(
    '200% text does not overflow the title bar',
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (container, _) = await _pump(tester, WindowChrome.windows);
      container.read(routerProvider).go(Routes.hosts);
      container.read(workbenchProvider.notifier)
        ..openPane(const SshTerminalContent(hostId: 'alpha'))
        ..openPane(const SshTerminalContent(hostId: 'beta'));
      await tester.settleFor();
      expect(tester.takeException(), isNull);
      expect(find.byType(WgTabChip), findsNWidgets(2));
    },
  );
}
