import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart' show SSHSocketError;
import 'package:test/test.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';

import 'helpers/fake_ssh.dart';

const short = Duration(milliseconds: 60);

Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> until(bool Function() condition, {Duration within = const Duration(seconds: 3)}) async {
  final deadline = DateTime.now().add(within);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('The condition did not hold within $within');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dir;
  late Map<String, Host> hosts;
  late FakeConnector connector;
  late ConnectionPool pool;

  ConnectionPool build({
    FakeConnector? using,
    Duration idleTimeout = const Duration(minutes: 5),
    Duration probeTimeout = const Duration(seconds: 5),
    Duration livenessTick = const Duration(seconds: 1),
  }) {
    connector = using ?? FakeConnector();
    final store = SqliteDocumentStore.open('${dir.path}/pool.db');
    final secrets = MemorySecretStore();
    return pool = ConnectionPool(
      lookup: (id) => hosts[id],
      hosts: HostRepository(store, secrets),
      keys: KeyRepository(store, secrets),
      broker: InteractionBroker(),
      idleTimeout: idleTimeout,
      probeTimeout: probeTimeout,
      livenessTick: livenessTick,
      connector: connector,
    );
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wg_pool');
    hosts = {
      'a': const Host(id: 'a', label: 'alpha', address: '10.0.0.1', username: 'u', keepAliveSeconds: 0),
      'b': const Host(id: 'b', label: 'beta', address: '10.0.0.2', username: 'u', jumpHostId: 'a', keepAliveSeconds: 0),
      'c': const Host(id: 'c', label: 'gamma', address: '10.0.0.3', username: 'u', jumpHostId: 'b', keepAliveSeconds: 0),
    };
  });

  tearDown(() async {
    await pool.dispose();
    dir.deleteSync(recursive: true);
  });

  group('connect', () {
    test('concurrent requests for one host share a single connection', () async {
      build(using: FakeConnector(manual: true));
      final first = pool.client('a');
      final second = pool.client('a');
      expect(connector.callsFor('a'), hasLength(1));
      expect(pool.status('a').state, LinkState.connecting);
      final made = connector.callsFor('a').single.succeed();
      expect(await first, same(made));
      expect(await second, same(made));
      await settle();
      expect(pool.status('a').state, LinkState.connected);
      expect(pool.openConnections, 1);
    });

    test('a failed connect reports the reason and the next request tries again', () async {
      build(using: FakeConnector(manual: true));
      final first = pool.client('a');
      connector.callsFor('a').single.fail(SSHSocketError(const SocketException('Connection reset')));
      await expectLater(first, throwsA(isA<SSHSocketError>()));
      await settle();
      expect(pool.status('a').state, LinkState.dropped);
      expect(pool.status('a').message, contains('Connection reset'));
      expect(pool.isOpen('a'), isFalse);
      final retry = pool.client('a');
      expect(connector.callsFor('a'), hasLength(2));
      connector.callsFor('a').last.succeed();
      await retry;
    });

    test('an unknown host fails without opening anything', () {
      build();
      expect(() => pool.client('missing'), throwsStateError);
      expect(connector.calls, isEmpty);
    });

    test('cancelConnect aborts a pending connect and leaves the host idle', () async {
      build(using: FakeConnector(manual: true));
      final pending = pool.client('a');
      pool.cancelConnect('a');
      await expectLater(pending, throwsA(isA<ConnectCancelledException>()));
      await settle();
      expect(connector.callsFor('a').single.cancel.isCancelled, isTrue);
      expect(pool.status('a'), LinkStatus.idle);
      expect(pool.isOpen('a'), isFalse);
    });

    test('cancelConnect does not touch a live connection', () async {
      build();
      final client = await pool.client('a') as FakeSshClient;
      pool.cancelConnect('a');
      await settle();
      expect(client.closed, isFalse);
      expect(pool.status('a').state, LinkState.connected);
    });
  });

  group('disconnect during connect', () {
    test('cancels the pending connect', () async {
      build(using: FakeConnector(manual: true));
      final pending = pool.client('a');
      await pool.disconnect('a');
      await expectLater(pending, throwsA(isA<ConnectCancelledException>()));
      expect(connector.callsFor('a').single.cancel.isCancelled, isTrue);
      expect(pool.status('a'), LinkStatus.idle);
      expect(pool.isOpen('a'), isFalse);
    });

    test('closes a client that arrives after the disconnect and never reports it connected', () async {
      build(using: FakeConnector(manual: true, honourCancel: false));
      final statuses = <LinkState>[];
      pool.changes.where((id) => id == 'a').listen((_) => statuses.add(pool.status('a').state));
      unawaited(pool.client('a').then((_) {}, onError: (_) {}));
      final closing = pool.disconnect('a');
      final late = connector.callsFor('a').single.succeed();
      await closing;
      await settle();
      expect(late.closed, isTrue);
      expect(pool.openConnections, 0);
      expect(pool.status('a'), LinkStatus.idle);
      expect(statuses, isNot(contains(LinkState.connected)));
    });

    test('sftp fails cleanly instead of crashing on a missing entry', () async {
      build(using: FakeConnector(manual: true, honourCancel: false));
      final sftp = expectLater(pool.sftp('a'), throwsStateError);
      final closing = pool.disconnect('a');
      connector.callsFor('a').single.succeed();
      await closing;
      await sftp;
    });

    test('a new request after the disconnect opens a fresh connection', () async {
      build(using: FakeConnector(manual: true));
      unawaited(pool.client('a').then((_) {}, onError: (_) {}));
      await pool.disconnect('a');
      final next = pool.client('a');
      expect(connector.callsFor('a'), hasLength(2));
      final made = connector.callsFor('a').last.succeed();
      expect(await next, same(made));
    });
  });

  group('sftp', () {
    test('one session is shared and reopened after it is dropped', () async {
      build();
      final first = await pool.sftp('a');
      final second = await pool.sftp('a');
      expect(second, same(first));
      final client = connector.clientFor('a')!;
      expect(client.sftpOpens, 1);
      pool.dropSftp('a');
      await pool.sftp('a');
      expect(client.sftpOpens, 2);
    });
  });

  group('idle timeout', () {
    test('an unused connection closes after the idle timeout', () async {
      build(idleTimeout: short);
      final client = await pool.client('a') as FakeSshClient;
      await until(() => client.closed);
      expect(pool.isOpen('a'), isFalse);
      expect(pool.status('a'), LinkStatus.idle);
    });

    test('a retained connection stays open until it is released', () async {
      build(idleTimeout: short);
      final client = await pool.client('a') as FakeSshClient;
      pool.retain('a');
      await Future<void>.delayed(short * 3);
      expect(client.closed, isFalse);
      pool.release('a');
      await until(() => client.closed);
    });

    test('a running operation holds the connection open', () async {
      build(idleTimeout: short);
      final gate = Completer<void>();
      final operation = pool.withOperation('a', (_) => gate.future);
      await settle();
      expect(pool.status('a').state, LinkState.busy);
      await Future<void>.delayed(short * 3);
      final client = connector.clientFor('a')!;
      expect(client.closed, isFalse);
      gate.complete();
      await operation;
      expect(pool.status('a').state, LinkState.connected);
      await until(() => client.closed);
    });

    test('releasing more often than retaining does not go negative', () async {
      build(idleTimeout: short);
      final client = await pool.client('a') as FakeSshClient;
      pool
        ..release('a')
        ..release('a')
        ..retain('a');
      await Future<void>.delayed(short * 3);
      expect(client.closed, isFalse);
    });
  });

  group('keep-alive', () {
    test('a host with a keep-alive interval is pinged on schedule', () async {
      hosts['a'] = hosts['a']!.copyWith(keepAliveSeconds: 1);
      build(livenessTick: const Duration(milliseconds: 20));
      final client = await pool.client('a') as FakeSshClient;
      expect(pool.livenessRunning, isTrue);
      await until(() => client.pings > 0);
      expect(client.closed, isFalse);
    });

    test('a host without a keep-alive interval is not pinged', () async {
      build(livenessTick: const Duration(milliseconds: 20));
      final client = await pool.client('a') as FakeSshClient;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(client.pings, 0);
    });

    test('an unanswered probe closes the link as dead', () async {
      build(probeTimeout: short);
      final client = await pool.client('a') as FakeSshClient
        ..hangingPing = Completer<void>();
      await pool.probe('a');
      expect(client.closed, isTrue);
      expect(pool.deadLinksClosed, 1);
      expect(pool.status('a').state, LinkState.dropped);
      expect(pool.status('a').message, SshErrorText.describe(const DeadLinkError()));
      expect(pool.isOpen('a'), isFalse);
    });

    test('liveness stops once the last connection closes', () async {
      build();
      await pool.client('a');
      expect(pool.livenessRunning, isTrue);
      await pool.disconnect('a');
      await settle();
      expect(pool.livenessRunning, isFalse);
    });
  });

  group('remote drops', () {
    test('a dropped link reports its cause', () async {
      build();
      (await pool.client('a') as FakeSshClient).drop(SSHSocketError(const SocketException('Broken pipe')));
      await settle();
      expect(pool.status('a').state, LinkState.dropped);
      expect(pool.status('a').message, 'The connection was lost: Broken pipe');
      expect(pool.isOpen('a'), isFalse);
    });

    test('a clean remote close says the connection closed', () async {
      build();
      final client = await pool.client('a') as FakeSshClient;
      await client.close();
      await settle();
      expect(pool.status('a').message, 'The connection closed');
    });
  });

  group('jump hosts', () {
    test('a chain connects each hop through the previous one', () async {
      build();
      final target = await pool.client('c') as FakeSshClient;
      final viaB = connector.clientFor('b')!;
      final viaA = connector.clientFor('a')!;
      expect(connector.calls.map((call) => call.host.id), ['a', 'b', 'c']);
      expect(target.jump, same(viaB));
      expect(viaB.jump, same(viaA));
      expect(connector.clientFor('a')!.jump, isNull);
      expect(pool.openConnections, 3);
    });

    test('a jump host stays open while the target uses it and idles after', () async {
      build(idleTimeout: short);
      final target = await pool.client('b') as FakeSshClient;
      pool.retain('b');
      final jump = connector.clientFor('a')!;
      await Future<void>.delayed(short * 3);
      expect(jump.closed, isFalse);
      await pool.disconnect('b');
      expect(target.closed, isTrue);
      await until(() => jump.closed);
    });

    test('a target that drops with an error releases its jump host', () async {
      build(idleTimeout: short);
      final target = await pool.client('b') as FakeSshClient;
      pool.retain('b');
      final jump = connector.clientFor('a')!;
      target.drop(SSHSocketError(const SocketException('reset')));
      await until(() => jump.closed);
      expect(pool.status('b').state, LinkState.dropped);
    });

    test('a failed target releases the jump host it retained', () async {
      build(using: FakeConnector(manual: true), idleTimeout: short);
      final target = pool.client('b');
      await until(() => connector.callsFor('a').isNotEmpty);
      final jump = connector.callsFor('a').single.succeed();
      await until(() => connector.callsFor('b').isNotEmpty);
      expect(connector.callsFor('b').single.jump, same(jump));
      connector.callsFor('b').single.fail(SSHSocketError(const SocketException('refused')));
      await expectLater(target, throwsA(isA<SSHSocketError>()));
      await until(() => jump.closed);
    });

    test('a failed jump host fails the target without opening it', () async {
      build(using: FakeConnector(manual: true));
      final target = pool.client('b');
      await until(() => connector.callsFor('a').isNotEmpty);
      connector.callsFor('a').single.fail(SSHSocketError(const SocketException('down')));
      await expectLater(target, throwsA(isA<SSHSocketError>()));
      expect(connector.callsFor('b'), isEmpty);
      await settle();
      expect(pool.status('b').state, LinkState.dropped);
    });
  });

  group('exec', () {
    test('runs on the pooled connection and reports the output', () async {
      build();
      final result = await pool.exec('a', 'uname');
      expect(result.succeeded, isTrue);
      expect(result.stdout, 'uname');
      expect(connector.callsFor('a'), hasLength(1));
    });

    test('turns a connect failure into a failed result', () async {
      build(using: FakeConnector(manual: true));
      final running = pool.exec('a', 'true');
      connector.callsFor('a').single.fail(SSHSocketError(const SocketException('refused')));
      final result = await running;
      expect(result.succeeded, isFalse);
      expect(result.error, contains('refused'));
    });
  });
}
