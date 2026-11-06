@Tags(['perf'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/probe.dart';

Future<void> main() async {
  if (!await Probe.available) {
    test('paragraph cost', () {}, skip: Probe.skipReason);
    return;
  }
  test('native cost of one cached glyph paragraph', () {
    final kept = <ui.Paragraph>[];
    final before = ProcessInfo.currentRss;
    for (var i = 0; i < 10240; i++) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'JetBrainsMono', fontSize: 13))
        ..pushStyle(TextStyle(color: Color(0xFF000000 | (i * 2654435761) & 0xFFFFFF), fontFamily: 'JetBrainsMono', fontSize: 13).getTextStyle())
        ..addText(String.fromCharCode(0x21 + i % 90));
      kept.add(builder.build()..layout(const ui.ParagraphConstraints(width: 100)));
    }
    final grown = ProcessInfo.currentRss - before;
    PerfLog.record('terminal.paragraph', {
      'paragraphs': kept.length,
      'rss_growth_mb': double.parse(mb(grown)),
      'kb_per_paragraph': (grown / kept.length / 1024).round(),
    });
  });
}
