@Tags(['perf'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/features/sftp/application/file_sort_key.dart';
import 'package:warpgate/features/sftp/utils/file_sorting.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

import 'support/probe.dart';

void main() {
  test('filter and sort 100k entries', () {
    expect(
      FileSorting.sorted(
        const [
          FileEntry(name: 'b', path: '/b', isDirectory: false),
          FileEntry(name: 'A', path: '/A', isDirectory: false),
          FileEntry(name: 'z', path: '/z', isDirectory: true),
        ],
        SortKey.name,
        ascending: true,
      ).map((e) => e.name),
      ['z', 'A', 'b'],
    );
    final entries = [
      for (var i = 0; i < 100000; i++)
        FileEntry(
          name: '${i.isEven ? 'Report' : 'data'}_${(i * 7919) % 100000}.log',
          path: '/var/log/x/$i',
          isDirectory: i % 50 == 0,
          size: i * 13,
          modified: DateTime(2026).add(Duration(minutes: i)),
        ),
    ];
    for (final key in [SortKey.name, SortKey.size]) {
      final watch = Stopwatch()..start();
      const runs = 5;
      for (var r = 0; r < runs; r++) {
        final visible = FileSorting.sorted(
          [
            for (final entry in entries)
              if (!entry.isHidden) entry,
          ],
          key,
          ascending: true,
        );
        expect(visible.length, entries.length);
      }
      PerfLog.record('sftp.visible', {
        'entries': entries.length,
        'sort': key.name,
        'ms_per_evaluation': (watch.elapsedMilliseconds / runs).round(),
      });
      expect(watch.elapsedMilliseconds / runs, lessThan(400));
    }
  });
}
