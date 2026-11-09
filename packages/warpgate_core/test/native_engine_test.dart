@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/engine/native/native_auth.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/features/connection/engine/native/native_ssh_client.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart' show CancelToken;

void main() {
  final keyPath = Platform.environment['WARPGATE_TEST_KEY'];
  final port = int.tryParse(Platform.environment['WARPGATE_TEST_PORT'] ?? '');
  final library = Platform.environment['WARPGATE_ENGINE_LIBRARY'];
  final skip = keyPath == null || port == null || library == null
      ? 'Set WARPGATE_TEST_KEY, WARPGATE_TEST_PORT and WARPGATE_ENGINE_LIBRARY to run'
      : null;
  final user = Platform.environment['USER'] ?? '';

  late String pem;
  late String encryptedPem;

  setUpAll(() async {
    if (skip != null) return;
    expect(await NativeEngine.ensureLoaded(), isTrue, reason: NativeEngine.loadError);
    pem = File(keyPath!).readAsStringSync();
    final dir = Directory.systemTemp.createTempSync('wg_native');
    final encrypted = '${dir.path}/locked';
    final made = await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', 'secret', '-f', encrypted]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    encryptedPem = File(encrypted).readAsStringSync();
    dir.deleteSync(recursive: true);
  });

  Future<NativeSshClient> connect(List<NativeCredential> credentials, {Future<String?> Function()? password}) =>
      NativeSshClient.connect(
        host: '127.0.0.1',
        port: port!,
        verify: (_, _) async => true,
        auth: NativeAuth(username: user, credentials: credentials, password: password),
      );

  test('a key that fails to decrypt falls through to the next method', () async {
    final client = await connect([KeyCredential(encryptedPem, 'wrong'), KeyCredential(pem, null)]);
    expect(client.isClosed, isFalse);
    expect(client.remoteVersion, startsWith('SSH-2.0-'));
    await client.close();
  }, skip: skip);

  test('a failed sign-in throws the key error', () async {
    Object? caught;
    try {
      await connect([KeyCredential(encryptedPem, 'wrong')], password: () async => null);
    } on Object catch (error) {
      caught = error;
    }
    expect(caught, isA<SSHKeyDecryptError>());
  }, skip: skip);

  test('a dropped link completes done with the real cause', () async {
    final client = await connect([KeyCredential(pem, null)]);
    final session = await client.execute(r'kill -9 $PPID');
    unawaited(session.stdout.drain<void>());
    unawaited(session.stderr.drain<void>());
    Object? cause;
    await client.done.then<void>((_) {}, onError: (Object error) => cause = error).timeout(const Duration(seconds: 10));
    expect(cause, isNotNull);
  }, skip: skip);

  test('a closed client completes done without an error', () async {
    final client = await connect([KeyCredential(pem, null)]);
    await client.close();
    await expectLater(client.done.timeout(const Duration(seconds: 10)), completes);
  }, skip: skip);

  test('large exec output arrives in full', () async {
    final client = await connect([KeyCredential(pem, null)]);
    final session = await client.execute('head -c 3000000 /dev/zero');
    var total = 0;
    final err = session.stderr.drain<void>();
    await session.stdout.forEach((Uint8List chunk) => total += chunk.length);
    await err;
    expect(total, 3000000);
    await client.close();
  }, skip: skip);

  test('stdin data is delivered before end of file', () async {
    final client = await connect([KeyCredential(pem, null)]);
    final session = await client.execute('cat');
    final out = session.stdout.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    unawaited(session.stderr.drain<void>());
    session.stdin.add(Uint8List.fromList(utf8.encode('piped')));
    await session.stdin.close();
    expect(utf8.decode(await out.timeout(const Duration(seconds: 10))), 'piped');
    await client.close();
  }, skip: skip);

  test('a cancelled connect fails with a cancellation error', () async {
    final cancel = CancelToken()..cancel();
    await expectLater(
      NativeSshClient.connect(
        host: '127.0.0.1',
        port: port!,
        cancel: cancel,
        verify: (_, _) async => true,
        auth: NativeAuth(username: user, credentials: [KeyCredential(pem, null)]),
      ),
      throwsA(isA<ConnectCancelledException>()),
    );
  }, skip: skip);

  test('aborting a write cancels the source stream and fails done', () async {
    final client = await connect([KeyCredential(pem, null)]);
    final sftp = await client.sftp();
    final path = '${Directory.systemTemp.path}/wg_abort_${DateTime.now().microsecondsSinceEpoch}';
    final file = await sftp.open(
      path,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    final cancelled = Completer<void>();
    final source = StreamController<Uint8List>(onCancel: cancelled.complete);
    final writer = file.write(source.stream);
    source.add(Uint8List.fromList(utf8.encode('partial')));
    await writer.abort();
    await expectLater(writer.done, throwsA(isA<SftpAbortError>()));
    await cancelled.future.timeout(const Duration(seconds: 5));
    await file.close();
    await sftp.remove(path);
    await sftp.close();
    await client.close();
  }, skip: skip);
}
