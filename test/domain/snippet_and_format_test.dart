import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/features/snippets/domain/snippet.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';

void main() {
  test('snippet variables with defaults', () {
    const snippet = Snippet(
      id: '1',
      name: 'r',
      body: 'systemctl {{action|restart}} {{ service }} && echo {{service}}',
    );
    expect(snippet.variables.map((v) => v.name), ['action', 'service']);
    expect(snippet.variables.first.fallback, 'restart');
    expect(
      snippet.render({'service': 'nginx'}),
      'systemctl restart nginx && echo nginx',
    );
  });

  test('format helpers', () {
    expect(Format.bytes(512), '512 B');
    expect(Format.bytes(1536), '1.5 KB');
    expect(Format.bytes(200 * 1024 * 1024), '200 MB');
    expect(Format.mode(0x1ED), 'rwxr-xr-x');
    expect(Format.octal(0x1A4), '644');
    expect(Format.duration(const Duration(milliseconds: 250)), '250 ms');
    expect(Format.duration(const Duration(seconds: 75)), '1m 15s');
    expect(Format.eta(1000, 0), '—');
    expect(Format.plural(1, 'host'), '1 host');
    expect(Format.plural(3, 'host'), '3 hosts');
  });

  test('speed meter averages over its window', () {
    final meter = SpeedMeter();
    final start = DateTime(2026);
    meter.add(0, start);
    expect(
      meter.add(1000, start.add(const Duration(seconds: 1))),
      closeTo(1000, 1),
    );
  });

  test('transfer job json round trip', () {
    final job = TransferJob(
      id: 'j',
      source: const TransferRef(hostId: 'a', path: '/x'),
      target: const TransferRef(path: '/y'),
      name: 'x',
      createdAt: DateTime(2026),
      isDirectory: true,
      completedFiles: const {'a/b'},
      partialFile: 'a/c',
      totalBytes: 10,
      doneBytes: 4,
    );
    final back = TransferJob.fromJson(job.toJson());
    expect(back.completedFiles, {'a/b'});
    expect(back.partialFile, 'a/c');
    expect(back.fraction, closeTo(0.4, 1e-9));
  });
}
