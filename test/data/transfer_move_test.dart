import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoints.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/data/file_checksum.dart';
import 'package:warpgate_core/features/transfers/data/transfer_engine.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

class ShortWriteEndpoint extends LocalEndpoint {
  @override
  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  }) async {
    await data.drain<void>();
    await File(path).writeAsBytes([1]);
  }
}

void main() {
  late Directory root;
  late Directory from;
  late Directory to;

  setUp(() {
    root = Directory.systemTemp.createTempSync('wg-move');
    from = Directory(p.join(root.path, 'from'))..createSync();
    to = Directory(p.join(root.path, 'to'))..createSync();
    Directory(p.join(from.path, 'site', 'css')).createSync(recursive: true);
    File(p.join(from.path, 'site', 'index.html')).writeAsStringSync('<h1>');
    File(p.join(from.path, 'site', 'css', 'a.css')).writeAsStringSync('a{}');
  });

  tearDown(() => root.deleteSync(recursive: true));

  TransferJob job({required bool move}) => TransferJob(
    id: 'j',
    source: TransferRef(hostId: 'a', path: p.join(from.path, 'site')),
    target: TransferRef(hostId: 'b', path: p.join(to.path, 'site')),
    name: 'site',
    isDirectory: true,
    createdAt: DateTime(2026),
    move: move,
  );

  Future<void> run(TransferJob job, FileEndpoint target) async {
    var current = job;
    await TransferEngine(
      endpointFor: (host) async => host == 'b' ? target : LocalEndpoint(),
      askConflict: (_) async =>
          (resolution: ConflictResolution.overwrite, applyToAll: true),
      checksum: (_, path) => FileChecksum.local(path),
    ).run(
      current,
      update: (change) => current = change(current),
      cancel: CancelToken(),
      policy: ConflictPolicy.overwrite,
    );
  }

  test('move deletes the source after the copy is verified', () async {
    await run(job(move: true), LocalEndpoint());
    expect(
      File(p.join(to.path, 'site', 'css', 'a.css')).readAsStringSync(),
      'a{}',
    );
    expect(Directory(p.join(from.path, 'site')).existsSync(), isFalse);
  });

  test('copy keeps the source', () async {
    await run(job(move: false), LocalEndpoint());
    expect(File(p.join(from.path, 'site', 'index.html')).existsSync(), isTrue);
  });

  test('a short write stops the move and keeps the source', () async {
    await expectLater(
      run(job(move: true), ShortWriteEndpoint()),
      throwsA(isA<VerificationFailed>()),
    );
    expect(File(p.join(from.path, 'site', 'index.html')).existsSync(), isTrue);
    expect(
      File(p.join(from.path, 'site', 'css', 'a.css')).existsSync(),
      isTrue,
    );
  });

  test('checksum output parses', () {
    expect(FileChecksum.parse('${'ab' * 32}  /tmp/x\n'), 'ab' * 32);
    expect(FileChecksum.parse(''), isNull);
  });
}
