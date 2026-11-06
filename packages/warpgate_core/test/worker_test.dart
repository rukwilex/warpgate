import 'dart:io';

import 'package:test/test.dart';
import 'package:warpgate_core/core/util/worker.dart';
import 'package:warpgate_core/features/transfers/data/file_checksum.dart';

void main() {
  test('one long-lived worker serves many calls and reports errors', () async {
    final worker = Worker.named('test');
    final results = await Future.wait([for (var i = 0; i < 200; i++) worker.run(() => i * 2)]);
    expect(results.last, 398);
    expect(worker.completed, 200);
    await expectLater(worker.run(() => throw StateError('boom')), throwsA(isA<WorkerError>()));
    await worker.close();
    expect(worker.running, isFalse);
  });

  test('local checksum runs on the io worker', () async {
    final file = File('${Directory.systemTemp.createTempSync().path}/a.txt')..writeAsStringSync('abc');
    expect(
      await FileChecksum.local(file.path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(Worker.named('io').running, isTrue);
    await Worker.closeAll();
  });
}
