import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/terminal/data/terminal_ingest.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';

class FloodBackend implements TerminalBackend {
  new() {
    controller
      ..onPause = () {
        pauses++;
      }
      ..onResume = pump;
  }

  final controller = StreamController<Uint8List>();
  final _done = Completer<void>();
  int acks = 0;
  int pauses = 0;
  int sent = 0;


  static final _chunk = Uint8List.fromList(
    List.generate(32 * 1024, (i) => i % 72 == 71 ? 10 : (i % 72 == 70 ? 13 : 120)),
  );

  void pump() {
    if (controller.isPaused || controller.isClosed) return;
    if (sent < 40 << 20) {
      controller.add(_chunk);
      sent += _chunk.length;
      Timer.run(pump);
      return;
    }
    if (!controller.isClosed) {
      controller.add(Uint8List.fromList('LAST\r\n'.codeUnits));
      unawaited(controller.close());
      _done.complete();
    }
  }

  @override
  int? get pid => null;

  @override
  Stream<Uint8List> get output => controller.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get connectionLost => false;

  @override
  void write(Uint8List data) {}

  @override
  void resize(int columns, int rows) {}

  @override
  void acknowledge() => acks++;

  @override
  void close() {}
}

TerminalSession session(FloodBackend backend) {
  final store = DriftDocumentStore(AppDatabase(NativeDatabase.memory()));
  final secrets = MemorySecretStore();
  return TerminalSession(
    id: 'flood',
    target: const LocalTarget(),
    openBackend: () async => backend,
    pool: ConnectionPool(
      lookup: (_) => null,
      hosts: HostRepository(store, secrets),
      keys: KeyRepository(store, secrets),
      broker: InteractionBroker(),
    ),
  );
}

void main() {
  test('a flood is bounded, paused at the source and drained in slices', () async {
    final backend = FloodBackend();
    final terminal = session(backend);
    await terminal.start();
    var peak = 0;
    var throttledSeen = false;
    final sampler = Timer.periodic(const Duration(milliseconds: 1), (_) {
      if (terminal.pendingBytes > peak) peak = terminal.pendingBytes;
      throttledSeen |= terminal.throttled;
    });
    backend.pump();
    await backend.done;
    while (terminal.pendingBytes > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    sampler.cancel();
    expect(backend.pauses, greaterThan(0));
    expect(throttledSeen, isTrue);
    expect(peak, lessThan((1 << 20) + 64 * 1024));
    expect(
      TerminalIngest.instance.longestRunMicros,
      lessThan(TerminalIngest.budget.inMicroseconds + 50000),
    );
    expect(terminal.tail(3), contains('LAST'));
    terminal.dispose();
  });
}
