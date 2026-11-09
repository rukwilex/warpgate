import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';

class QuietBackend implements TerminalBackend {
  final _output = StreamController<Uint8List>();
  final _done = Completer<void>();
  bool closed = false;

  @override
  int? get pid => null;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get connectionLost => false;

  @override
  void write(Uint8List data) {}

  @override
  void resize(int columns, int rows) {}

  @override
  void acknowledge() {}

  @override
  void close() {
    closed = true;
    if (!_done.isCompleted) _done.complete();
    unawaited(_output.close());
  }
}

void main() {
  late Completer<TerminalBackend> opening;
  late TerminalSession session;

  setUp(() {
    opening = Completer<TerminalBackend>();
    final store = DriftDocumentStore(AppDatabase(NativeDatabase.memory()));
    final secrets = MemorySecretStore();
    session = TerminalSession(
      id: 'cancel',
      target: const LocalTarget(),
      openBackend: () => opening.future,
      pool: ConnectionPool(
        lookup: (_) => null,
        hosts: HostRepository(store, secrets),
        keys: KeyRepository(store, secrets),
        broker: InteractionBroker(),
      ),
    );
  });

  test('cancelling a pending connect leaves the pane idle and drops the late backend', () async {
    final started = session.start();
    expect(session.status.value.state, LinkState.connecting);
    session.cancelConnect();
    expect(session.status.value.state, LinkState.idle);
    expect(session.status.value.message, 'Connecting was cancelled');
    final backend = QuietBackend();
    opening.complete(backend);
    await started;
    expect(backend.closed, isTrue);
    expect(session.isRunning, isFalse);
    expect(session.status.value.state, LinkState.idle);
  });

  test('cancel does nothing once the session runs', () async {
    final backend = QuietBackend();
    opening.complete(backend);
    await session.start();
    session.cancelConnect();
    expect(session.isRunning, isTrue);
    expect(session.status.value.state, LinkState.connected);
    expect(backend.closed, isFalse);
  });
}
