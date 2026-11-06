@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../widgets/terminal_surface_test.dart' show localSession;
import 'support/load.dart';
import 'support/probe.dart';

Future<void> main() async {
  if (!await Probe.available) {
    test('terminal resize', () {}, skip: Probe.skipReason);
    return;
  }
  final probe = await Probe.connect();

  test('resize a pane with 10k lines of scrollback', () async {
    final session = localSession();
    addTearDown(session.dispose);
    session.terminal.resize(120, 40);
    final text = Load.buildLog(10050);
    for (var i = 0; i < text.length; i += 4096) {
      session.terminal.write(text.substring(i, (i + 4096).clamp(0, text.length)));
    }
    final before = await probe.heap();
    final watch = Stopwatch()..start();
    session.resize(100, 40);
    final first = watch.elapsedMilliseconds;
    watch.reset();
    session.resize(140, 40);
    final second = watch.elapsedMilliseconds;
    final after = await probe.heap();
    final lines = session.terminal.mainBuffer.lines.length;
    var packed = 0;
    for (var i = 0; i < lines; i++) {
      if (session.terminal.mainBuffer.lines[i].isPacked) packed++;
    }
    PerfLog.record('terminal.resize', {
      'lines': lines,
      'first_resize_ms': first,
      'second_resize_ms': second,
      'heap_growth_mb': double.parse(mb(after.total - before.total)),
      'packed_after': packed,
    });
    expect(lines - packed, lessThan(200), reason: 'scrollback must stay compact after a resize');
  });
}
