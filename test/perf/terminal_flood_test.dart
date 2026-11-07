@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/presentation/terminal_surface.dart';
import 'package:xterm/xterm.dart';

import '../helpers/harness.dart';
import '../widgets/terminal_surface_test.dart' show localSession;
import 'support/load.dart';
import 'support/probe.dart';

const int _chunk = 16 * 1024;

List<List<int>> _chunks(String text) {
  final bytes = utf8.encode(text);
  return [
    for (var i = 0; i < bytes.length; i += _chunk)
      bytes.sublist(i, (i + _chunk).clamp(0, bytes.length)),
  ];
}

Map<String, String> _loads() => {
  'yes': Load.yes(8 << 20),
  'find': Load.paths(160000),
  'build_log': Load.buildLog(90000),
  'full_screen': Load.fullScreen(400),
  'true_color': Load.trueColor(6000),
};

Future<void> main() async {
  if (!await Probe.available) {
    test('terminal flood', () {}, skip: Probe.skipReason);
    return;
  }
  final probe = await Probe.connect();

  test('ingest throughput on the UI isolate', () async {
    for (final MapEntry(key: name, value: text) in _loads().entries) {
      final chunks = _chunks(text);
      final megabytes = chunks.fold<int>(0, (s, c) => s + c.length) / (1 << 20);
      var best = double.infinity;
      var worst = 0;
      for (var round = 0; round < 4; round++) {
        final terminal = Terminal(maxLines: 10000)
          ..reflowEnabled = false
          ..resize(120, 40);
        const decoder = Utf8Decoder(allowMalformed: true);
        final watch = Stopwatch()..start();
        var roundWorst = 0;
        for (final chunk in chunks) {
          final start = watch.elapsedMicroseconds;
          final data = decoder.convert(chunk);
          terminal.write(data);
          FolderTracking.parseOsc7(data);
          final spent = watch.elapsedMicroseconds - start;
          if (spent > roundWorst) roundWorst = spent;
        }
        if (round == 0) continue;
        final seconds = watch.elapsedMicroseconds / 1e6;
        if (seconds < best) {
          best = seconds;
          worst = roundWorst;
        }
      }
      PerfLog.record('terminal.ingest', {
        'load': name,
        'mb': double.parse(megabytes.toStringAsFixed(1)),
        'mb_per_s': double.parse((megabytes / best).toStringAsFixed(1)),
        'worst_chunk_ms': worst / 1000,
        'ms_per_16kb': double.parse((best * 1000 / chunks.length).toStringAsFixed(3)),
      });
    }
  });

  testWidgets('paint cost per frame while output floods', (tester) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final session = localSession();
    addTearDown(session.dispose);
    final controller = TerminalController();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 1400,
          height: 900,
          child: TerminalSurface(
            session: session,
            controller: controller,
            focusNode: focus,
            theme: TerminalThemes.defaultTheme,
            cursorType: TerminalCursorType.block,
            fontSize: 13,
            onFontSize: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final rssStart = ProcessInfo.currentRss;
    for (final MapEntry(key: name, value: text) in _loads().entries) {
      final chunks = _chunks(text).take(300).toList();
      var rebuilds = 0;
      debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
      final watch = Stopwatch()..start();
      var worst = 0;
      for (final chunk in chunks) {
        session.terminal.write(utf8.decode(chunk, allowMalformed: true));
        final start = watch.elapsedMicroseconds;
        await tester.pump(const Duration(milliseconds: 16));
        final spent = watch.elapsedMicroseconds - start;
        if (spent > worst) worst = spent;
      }
      debugOnRebuildDirtyWidget = null;
      PerfLog.record('terminal.frame', {
        'load': name,
        'rss_mb': double.parse(mb(ProcessInfo.currentRss)),
        'frames': chunks.length,
        'avg_frame_ms': double.parse((watch.elapsedMicroseconds / 1000 / chunks.length).toStringAsFixed(2)),
        'worst_frame_ms': worst / 1000,
        'rebuilt_elements_per_frame': rebuilds / chunks.length,
      });
    }
    expect(ParagraphCache.instance.length, lessThanOrEqualTo(ParagraphCache.maximumSize));
    final rssBeforeGc = ProcessInfo.currentRss;
    final heap = await tester.runAsync(probe.heap);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    PerfLog.record('terminal.frame.memory', {
      'rss_before_gc_mb': double.parse(mb(rssBeforeGc)),
      'rss_after_gc_mb': double.parse(mb(ProcessInfo.currentRss)),
      'rss_growth_mb': double.parse(mb(ProcessInfo.currentRss - rssStart)),
      'heap_mb': double.parse(mb(heap!.total)),
    });
  });
}
