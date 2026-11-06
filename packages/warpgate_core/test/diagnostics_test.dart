import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';
import 'package:warpgate_core/core/diagnostics/perf_checks.dart';
import 'package:warpgate_core/core/diagnostics/process_stats.dart';
import 'package:warpgate_core/core/diagnostics/watchdog.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';

void main() {
  test('the log rotates by size and never keeps more than its file count', () async {
    final dir = Directory.systemTemp.createTempSync('wg_log');
    final log = AppLog(directory: dir.path, maxFileBytes: 4096, maxFiles: 3);
    for (var round = 0; round < 40; round++) {
      for (var i = 0; i < 20; i++) {
        log.info('test', 'line $round $i ${'x' * 40}');
      }
      await log.flush();
    }
    final files = dir.listSync().whereType<File>().map((f) => f.path.split('/').last).toList()..sort();
    expect(files.length, lessThanOrEqualTo(3));
    expect(files, contains('warpgate.log'));
    for (final file in dir.listSync().whereType<File>()) {
      expect(file.lengthSync(), lessThan(4096 * 2));
    }
    expect(log.recent.length, lessThanOrEqualTo(500));
    dir.deleteSync(recursive: true);
  });

  test('a blocked isolate is reported as a stall with what it was doing', () async {
    Stall? seen;
    final watchdog = Watchdog(threshold: const Duration(milliseconds: 400), onStall: (stall) => seen = stall);
    await watchdog.start();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    Watchdog.during(Activity.fileList, () {
      final until = DateTime.now().add(const Duration(milliseconds: 1200));
      while (DateTime.now().isBefore(until)) {}
    });
    for (var i = 0; i < 30 && seen == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await watchdog.stop();
    expect(seen, isNotNull);
    expect(seen!.activity, Activity.fileList);
    expect(seen!.duration, greaterThan(const Duration(milliseconds: 800)));
    expect(watchdog.stalls, isNotEmpty);
  });

  test('cpu time can be read on this platform', () {
    final meter = CpuMeter()..sample();
    var x = 0;
    for (var i = 0; i < 20000000; i++) {
      x ^= i;
    }
    expect(x, isNot(-1));
    meter.sample();
    expect(ProcessStats.cpuTime(), isNotNull);
    expect(meter.percent, greaterThan(0));
  });

  test('perf checks flag memory, latency and stalls', () {
    final ok = PerfChecks.from({
      'memory': {'rss_mb': 200, 'soft_limit_mb': 1536, 'terminals_mb': 3.0},
      'cpu_percent': 0.5,
      'event_loop': {'p99_ms': 2.0, 'max_ms': 9.0},
      'frames': {'frames': 100, 'janky_over_16ms': 0},
      'stalls': <Object>[],
      'sessions': <Object>[],
    });
    expect(ok.every((check) => check.ok), isTrue);
    final bad = PerfChecks.from({
      'memory': {'rss_mb': 2000, 'soft_limit_mb': 1536},
      'cpu_percent': 80,
      'event_loop': {'p99_ms': 120.0, 'max_ms': 3000.0},
      'frames': {'frames': 100, 'janky_over_16ms': 50},
      'stalls': [{'ms': 3000}],
      'sessions': <Object>[],
    });
    expect(bad.where((check) => !check.ok).length, 5);
  });

  test('reconnect delays spread with jitter and stay near the step', () {
    final random = Random(1);
    final delays = {for (var i = 0; i < 50; i++) Backoff.delay(3, random: random).inMilliseconds};
    expect(delays.length, greaterThan(10));
    for (final delay in delays) {
      expect(delay, inInclusiveRange(6400, 9600));
    }
  });
}
