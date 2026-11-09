import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
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

  Future<TransferJob> pausedThenResumed(
    TransferJob start,
    String trigger,
    ConflictResolution Function(ConflictRequest request) answer,
  ) async {
    var job = start;
    final cancel = CancelToken();
    final local = LocalEndpoint();
    Future<ConflictAnswer> ask(ConflictRequest request) async => (resolution: answer(request), applyToAll: false);
    await expectLater(
      TransferEngine(
        endpointFor: (hostId) async => hostId == null ? local : CancellingEndpoint(cancel, trigger),
        askConflict: ask,
        progressEvery: const Duration(hours: 1),
      ).run(job, update: (change) => job = change(job), cancel: cancel, policy: ConflictPolicy.ask),
      throwsA(isA<TransferCancelled>()),
    );
    job = TransferJob.fromJson(job.toJson());
    await TransferEngine(
      endpointFor: (_) async => local,
      askConflict: ask,
      progressEvery: const Duration(hours: 1),
    ).run(job, update: (change) => job = change(job), cancel: CancelToken(), policy: ConflictPolicy.ask);
    return job;
  }

  test('a resumed move keeps the source of a file the user skipped', () async {
    target.createSync();
    File('${target.path}/a.txt').writeAsStringSync('keep me');
    final job = await pausedThenResumed(
      TransferJob(
        id: 'm',
        source: TransferRef(path: source.path),
        target: TransferRef(path: target.path, hostId: 'remote'),
        name: 'src',
        createdAt: DateTime(2026),
        isDirectory: true,
        move: true,
      ),
      'c.txt',
      (_) => ConflictResolution.skip,
    );
    expect(File('${source.path}/a.txt').existsSync(), isTrue);
    expect(File('${target.path}/a.txt').readAsStringSync(), 'keep me');
    expect(File('${source.path}/b.txt').existsSync(), isFalse);
    expect(job.skippedFiles, {'a.txt'});
  });

  test('resuming a renamed file continues the new copy and leaves the original alone', () async {
    target.createSync();
    File('${target.path}/c.txt').writeAsStringSync('x');
    await pausedThenResumed(
      TransferJob(
        id: 'r',
        source: TransferRef(path: source.path),
        target: TransferRef(path: target.path, hostId: 'remote'),
        name: 'src',
        createdAt: DateTime(2026),
        isDirectory: true,
      ),
      'c (1).txt',
      (_) => ConflictResolution.rename,
    );
    expect(File('${target.path}/c.txt').readAsStringSync(), 'x');
    expect(File('${target.path}/c (1).txt').readAsStringSync(), 'payload of c.txt');
  });
}
