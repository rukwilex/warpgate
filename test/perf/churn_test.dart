@Tags(['perf'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

import '../helpers/harness.dart';
import 'support/probe.dart';

const _tracked = {
  'TerminalSession',
  'Terminal',
  'BufferLine',
  'TerminalController',
  'FocusNode',
  'ScrollController',
  'TextEditingController',
  'AnimationController',
  '_Timer',
  '_ControllerSubscription',
  '_BufferingStreamSubscription',
  '_SyncBroadcastStreamController',
  '_AsyncStreamController',
  'ValueNotifier',
  'Paragraph',
  '_NativeParagraph',
};

Future<void> main() async {
  if (!await Probe.available) {
    test('churn', () {}, skip: Probe.skipReason);
    return;
  }
  testWidgets('open and close panes, splits and file panels', (tester) async {
    final probe = (await tester.runAsync(Probe.connect))!;
    final container = await pumpApp(
      tester,
      overrides: [sessionAutoStartProvider.overrideWithValue(false)],
    );
    final bench = container.read(workbenchProvider.notifier);
    await tester.settleFor();
    final before = (await tester.runAsync(() => probe.instances(_tracked)))!;
    final rss0 = ProcessInfo.currentRss;
    final rounds = int.parse(Platform.environment['WARPGATE_PERF_ROUNDS'] ?? '1000');
    final watch = Stopwatch()..start();
    for (var i = 0; i < rounds; i++) {
      final id = bench.openPane(const LocalTerminalContent());
      await tester.pump(const Duration(milliseconds: 16));
      final split = bench.openPane(const LocalTerminalContent(), placement: PanePlacement.splitRight);
      await tester.pump(const Duration(milliseconds: 16));
      if (i % 10 == 0) {
        final files = bench.openPane(
          const SftpContent(left: SftpSide()),
          placement: PanePlacement.splitDown,
        );
        await tester.pump(const Duration(milliseconds: 16));
        bench.closePane(files);
      }
      bench.closePane(split);
      bench.closePane(id);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.settleFor(const Duration(seconds: 2));
    final after = (await tester.runAsync(() => probe.instances(_tracked)))!;
    final growth = {
      for (final name in _tracked)
        if ((after[name] ?? 0) != (before[name] ?? 0)) name: (after[name] ?? 0) - (before[name] ?? 0),
    };
    if (Platform.environment['WARPGATE_PERF_PATHS'] != null) {
      for (final name in ['TextEditingController', 'TerminalSession', '_ControllerSubscription']) {
        final paths = (await tester.runAsync(() => probe.retainingPaths(name, limit: 2)))!;
        for (final path in paths) {
          stdout.writeln('RETAIN $name: $path');
        }
      }
    }
    PerfLog.record('churn.panes', {
      'rounds': rounds,
      'seconds': watch.elapsed.inSeconds,
      'live_sessions': container.read(terminalSessionsProvider).all.length,
      'instance_growth': growth,
      'rss_growth_mb': double.parse(mb(ProcessInfo.currentRss - rss0)),
      'live_objects': LiveObjects.snapshot(),
    });
    expect(container.read(terminalSessionsProvider).all, isEmpty);
    expect(LiveObjects.count('terminal session'), 0);
    expect(growth['TerminalSession'] ?? 0, lessThanOrEqualTo(2));
    expect(growth['Terminal'] ?? 0, lessThanOrEqualTo(2));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
