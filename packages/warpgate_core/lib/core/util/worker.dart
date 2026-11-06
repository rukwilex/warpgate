import 'dart:async';
import 'dart:isolate';

class WorkerError implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

class Worker {
  new _(this.name);

  static final Map<String, Worker> _named = {};

  static Worker named(String name) => _named[name] ??= Worker._(name);

  static Iterable<Worker> get all => _named.values;

  static Future<void> closeAll() async {
    for (final worker in List.of(_named.values)) {
      await worker.close();
    }
  }

  final String name;
  Isolate? _isolate;
  SendPort? _send;
  ReceivePort? _receive;
  Future<void>? _starting;
  final Map<int, Completer<Object?>> _pending = {};
  int _next = 0;
  int completed = 0;

  bool get running => _isolate != null;

  int get pending => _pending.length;

  Future<R> run<R>(FutureOr<R> Function() task) async {
    await (_starting ??= _start());
    final id = _next++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _send!.send((id, task));
    return (await completer.future) as R;
  }

  Future<void> _start() async {
    final receive = ReceivePort('worker $name');
    final ready = Completer<SendPort>();
    receive.listen((Object? message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      if (message is (int, bool, Object?)) {
        final (id, ok, value) = message;
        final completer = _pending.remove(id);
        if (completer == null) return;
        completed++;
        if (ok) {
          completer.complete(value);
        } else {
          completer.completeError(WorkerError('$value'));
        }
      }
    });
    _receive = receive;
    _isolate = await Isolate.spawn(_main, receive.sendPort, debugName: 'worker $name');
    _send = await ready.future;
  }

  static void _main(SendPort reply) {
    final port = ReceivePort();
    reply.send(port.sendPort);
    port.listen((Object? message) async {
      final (id, task) = message! as (int, FutureOr<Object?> Function());
      try {
        reply.send((id, true, await task()));
      } on Object catch (error) {
        reply.send((id, false, '$error'));
      }
    });
  }

  Future<void> close() async {
    _named.remove(name);
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receive?.close();
    _receive = null;
    _send = null;
    _starting = null;
    for (final completer in _pending.values) {
      completer.completeError(const WorkerError('The worker was stopped'));
    }
    _pending.clear();
  }
}
