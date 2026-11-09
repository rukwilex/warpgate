import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart' show SSHSocketError;
import 'package:test/test.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';

import 'helpers/fake_ssh.dart';

Future<int> freePort() async {
  final probe = await ServerSocket.bind('127.0.0.1', 0);
  final port = probe.port;
  await probe.close();
  return port;
}

Future<bool> listening(int port) async {
  try {
    final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  }
}

void main() {
  late Directory dir;
  late FakeConnector connector;
  late ConnectionPool pool;
  late PortForwarder forwarder;
  late PortForwardSpec spec;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('wg_forward');
    final store = SqliteDocumentStore.open('${dir.path}/f.db');
    final secrets = MemorySecretStore();
    connector = FakeConnector();
    const host = Host(id: 'a', label: 'alpha', address: '10.0.0.1', username: 'u', keepAliveSeconds: 0);
    pool = ConnectionPool(
      lookup: (id) => id == 'a' ? host : null,
      hosts: HostRepository(store, secrets),
      keys: KeyRepository(store, secrets),
      broker: InteractionBroker(),
      idleTimeout: const Duration(milliseconds: 60),
      connector: connector,
    );
    forwarder = PortForwarder(pool);
    spec = PortForwardSpec(
      id: 'web',
      kind: ForwardKind.local,
      bindPort: await freePort(),
      targetHost: 'localhost',
      targetPort: 80,
    );
  });

  tearDown(() async {
    await forwarder.dispose();
    await pool.dispose();
    dir.deleteSync(recursive: true);
  });

  test('stopHost stops every forward of the host and lets the connection idle out', () async {
    await forwarder.start('a', spec);
    expect(forwarder.isRunning('a', 'web'), isTrue);
    expect(await listening(spec.bindPort), isTrue);
    await forwarder.stopHost('a');
    expect(forwarder.forwards.single.state, ForwardState.stopped);
    expect(await listening(spec.bindPort), isFalse);
    final client = connector.clientFor('a')!;
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!client.closed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(client.closed, isTrue);
  });

  test('a dropped connection fails the forward and frees its local port', () async {
    await forwarder.start('a', spec);
    connector.clientFor('a')!.drop(SSHSocketError(const SocketException('reset')));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(forwarder.forwards.single.state, ForwardState.failed);
    expect(await listening(spec.bindPort), isFalse);
    await forwarder.start('a', spec);
    expect(forwarder.isRunning('a', 'web'), isTrue);
  });
}
