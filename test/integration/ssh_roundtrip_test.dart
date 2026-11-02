@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/secret_store.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/connection/data/connection_pool.dart';
import 'package:warpgate/features/hosts/data/host_repository.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/keys/data/key_codec.dart';
import 'package:warpgate/features/keys/data/key_repository.dart';
import 'package:warpgate/features/settings/domain/app_settings.dart';
import 'package:warpgate/features/sftp/data/endpoints.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/transfers/data/transfer_engine.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';

void main() {
  final keyPath = Platform.environment['WARPGATE_TEST_KEY'];
  final port = int.tryParse(Platform.environment['WARPGATE_TEST_PORT'] ?? '');
  final skip = keyPath == null || port == null
      ? 'Set WARPGATE_TEST_KEY and WARPGATE_TEST_PORT to run'
      : null;

  late ConnectionPool pool;
  late Host host;
  late Host second;
  late InteractionBroker broker;
  late StreamSubscription<InteractionRequest<Object?>> answers;

  setUp(() async {
    if (skip != null) return;
    final store = DocumentStore(AppDatabase(NativeDatabase.memory()));
    final secrets = MemorySecretStore();
    final keys = KeyRepository(store, secrets);
    final material = KeyCodec.parse(File(keyPath!).readAsStringSync());
    final key = await keys.save(name: 'test', material: material);
    final user = Platform.environment['USER']!;
    host = Host(
      id: 'a',
      label: 'local-a',
      address: '127.0.0.1',
      port: port!,
      username: user,
      auth: AuthMethod.key,
      keyId: key.id,
    );
    second = Host(
      id: 'b',
      label: 'local-b',
      address: '127.0.0.1',
      port: port,
      username: user,
      auth: AuthMethod.key,
      keyId: key.id,
      jumpHostId: 'a',
    );
    final hosts = {host.id: host, second.id: second};
    broker = InteractionBroker()..attach();
    answers = broker.requests.listen((request) {
      if (request is HostKeyRequest) {
        request.respond(HostKeyVerdict.trustAndSave);
      }
    });
    pool = ConnectionPool(
      lookup: (id) => hosts[id],
      hosts: HostRepository(store, secrets),
      keys: keys,
      broker: broker,
    );
  });

  tearDown(() async {
    if (skip != null) return;
    await answers.cancel();
    await pool.dispose();
  });

  test('exec returns stdout, stderr and exit code', () async {
    final result = await pool.exec(host.id, 'echo out; echo err >&2; exit 3');
    expect(result.stdout.trim(), 'out');
    expect(result.stderr.trim(), 'err');
    expect(result.exitCode, 3);
  }, skip: skip);

  test('jump host chain reaches the target', () async {
    final result = await pool.exec(second.id, 'echo via-jump');
    expect(result.stdout.trim(), 'via-jump');
    expect(pool.isOpen(host.id), isTrue);
  }, skip: skip);

  test('sftp write, list, read and host to host stream', () async {
    final a = SftpEndpoint(await pool.sftp(host.id), label: 'a');
    final b = SftpEndpoint(await pool.sftp(second.id), label: 'b');
    final dir = '/tmp/warpgate-it-${DateTime.now().microsecondsSinceEpoch}';
    await a.createDirectory(dir);
    await a.createDirectory('$dir/src');
    final payload = Uint8List.fromList(
      List<int>.generate(300000, (i) => i % 251),
    );
    await a.writeAll('$dir/src/blob.bin', payload);
    await a.writeAll(
      '$dir/src/note.txt',
      Uint8List.fromList(utf8.encode('hello')),
    );
    await a.setMode('$dir/src/note.txt', 0x1ED);
    final listed = await a.list('$dir/src');
    expect(listed.map((e) => e.name).toSet(), {'blob.bin', 'note.txt'});

    final engine = TransferEngine(
      endpointFor: (id) async => id == host.id ? a : b,
      askConflict: (request) async =>
          (resolution: ConflictResolution.overwrite, applyToAll: true),
    );
    var job = TransferJob(
      id: 't',
      source: TransferRef(hostId: host.id, path: '$dir/src'),
      target: TransferRef(hostId: second.id, path: '$dir/dst'),
      name: 'src',
      isDirectory: true,
      createdAt: DateTime.now(),
    );
    await engine.run(
      job,
      update: (change) => job = change(job),
      cancel: CancelToken(),
      policy: ConflictPolicy.overwrite,
    );
    expect(job.doneBytes, payload.length + 5);
    expect(await b.readAll('$dir/dst/blob.bin', maxBytes: 1 << 20), payload);
    final copied = await b.stat('$dir/dst/note.txt');
    expect(copied!.mode! & 0x1FF, 0x1ED);
    await a.deleteDirectory(dir);
    expect(await a.exists(dir), isFalse);
  }, skip: skip);

  test('terminal session runs a shell and reports tmux missing', () async {
    final session = TerminalSession(
      id: 'p',
      target: SshTarget(host: host, tmuxSession: 'wg-test'),
      pool: pool,
    );
    await session.start();
    session.send('echo marker-\$((40+2))\r');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(session.tail(50), contains('marker-42'));
    final hasTmux = (await pool.exec(host.id, 'command -v tmux')).succeeded;
    if (!hasTmux) {
      expect(session.notice.value, contains('tmux is not installed'));
    }
    session.dispose();
  }, skip: skip);
}
