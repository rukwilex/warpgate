@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'support/load.dart';
import 'support/probe.dart';

Future<void> main() async {
  if (!await Probe.available) {
    test('terminal memory', () {}, skip: Probe.skipReason);
    return;
  }
  final probe = await Probe.connect();

  for (final (columns, lines) in [(80, 10000), (200, 10000), (80, 100000), (200, 100000)]) {
    test('scrollback memory $columns columns, $lines lines', () async {
      final before = await probe.heap();
      final terminal = Terminal(maxLines: lines)
        ..reflowEnabled = false
        ..resize(columns, 50);
      final text = Load.buildLog(lines + 50);
      for (var i = 0; i < text.length; i += 4096) {
        terminal.write(text.substring(i, (i + 4096).clamp(0, text.length)));
      }
      final after = await probe.heap();
      final held = after.total - before.total;
      final perLine = held / lines;
      PerfLog.record('terminal.scrollback', {
        'columns': columns,
        'lines': lines,
        'heap_bytes': held,
        'bytes_per_line': perLine.round(),
        'mb_per_100k_lines': double.parse(mb((perLine * 100000).round())),
        'rss_delta_mb': double.parse(mb(after.rss - before.rss)),
        'buffer_lines': terminal.mainBuffer.lines.length,
      });
      expect(terminal.mainBuffer.lines.length, lessThanOrEqualTo(lines));
      expect(perLine, lessThan(lines >= 100000 ? 600 : 1200), reason: 'scrollback bytes per line');
    });
  }
}
