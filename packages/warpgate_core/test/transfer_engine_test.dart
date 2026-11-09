import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoints.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/data/transfer_engine.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

class CancellingEndpoint extends LocalEndpoint {
  new(this.cancel, this.trigger);

  final CancelToken cancel;
  final String trigger;

  @override
  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  }) async {
    if (path.endsWith(trigger)) {
      await File(path).writeAsString('pa');
      this.cancel.cancel();
      this.cancel.throwIfCancelled();
    }
    await super.write(path, data, offset: offset, onProgress: onProgress, cancel: cancel);
  }
}

void main() {
  late Directory root;
  late Directory source;
  late Directory target;

  setUp(() {
    root = Directory.systemTemp.createTempSync('wg_engine');
    source = Directory('${root.path}/src')..createSync();
    target = Directory('${root.path}/dst');
    for (final name in ['a.txt', 'b.txt', 'c.txt']) {
      File('${source.path}/$name').writeAsStringSync('payload of $name');
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('a cancelled transfer records the finished files and the one in flight', () async {
    final cancel = CancelToken();
    final local = LocalEndpoint();
    final sink = CancellingEndpoint(cancel, 'c.txt');
    var job = TransferJob(
      id: 'j',
      source: TransferRef(path: source.path),
      target: TransferRef(path: target.path, hostId: 'remote'),
      name: 'src',
      createdAt: DateTime(2026),
      isDirectory: true,
    );
    final engine = TransferEngine(
      endpointFor: (hostId) async => hostId == null ? local : sink,
      askConflict: (request) async => request.fallback,
      progressEvery: const Duration(hours: 1),
    );
    await expectLater(
      engine.run(
        job,
        update: (change) => job = change(job),
        cancel: cancel,
        policy: ConflictPolicy.ask,
      ),
      throwsA(isA<TransferCancelled>()),
    );
    expect(job.completedFiles, {'a.txt', 'b.txt'});
    expect(job.partialFile, 'c.txt');
    expect(job.filesDone, 2);
  });

  test('resuming after a cancel continues the partial file without asking', () async {
    final cancel = CancelToken();
    final local = LocalEndpoint();
    var job = TransferJob(
      id: 'j',
      source: TransferRef(path: source.path),
      target: TransferRef(path: target.path, hostId: 'remote'),
      name: 'src',
      createdAt: DateTime(2026),
      isDirectory: true,
    );
    await expectLater(
      TransferEngine(
        endpointFor: (hostId) async => hostId == null ? local : CancellingEndpoint(cancel, 'c.txt'),
        askConflict: (request) async => request.fallback,
        progressEvery: const Duration(hours: 1),
      ).run(job, update: (change) => job = change(job), cancel: cancel, policy: ConflictPolicy.ask),
      throwsA(isA<TransferCancelled>()),
    );
    var asked = 0;
    await TransferEngine(
      endpointFor: (_) async => local,
      askConflict: (request) async {
        asked++;
        return request.fallback;
      },
      progressEvery: const Duration(hours: 1),
    ).run(job, update: (change) => job = change(job), cancel: CancelToken(), policy: ConflictPolicy.ask);
    expect(asked, 0);
    expect(File('${target.path}/c.txt').readAsStringSync(), 'payload of c.txt');
    expect(job.completedFiles, {'a.txt', 'b.txt', 'c.txt'});
  });
}
