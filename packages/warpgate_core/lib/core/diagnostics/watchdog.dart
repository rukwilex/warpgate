import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:warpgate_core/core/platform/native.dart';

enum Activity {
  idle('Idle'),
  frame('Drawing the window'),
  terminalIngest('Reading terminal output'),
  terminalResize('Resizing a terminal'),
  transfer('Updating transfers'),
  fileList('Listing files'),
  ssh('SSH traffic'),
  storage('Reading or writing the database'),
  ipc('A command line request'),
  mcp('An MCP request'),
  memoryTrim('Freeing memory');

  const Activity(this.label);

  final String label;
}

class Stall {
  const new({required this.at, required this.duration, required this.activity, this.stack});

  factory fromJson(Map<String, Object?> json) => Stall(
    at: DateTime.parse(json['at']! as String),
    duration: Duration(milliseconds: json['ms']! as int),
    activity: Activity.values.byName(json['activity']! as String),
    stack: json['stack'] as String?,
  );

  final DateTime at;
  final Duration duration;
  final Activity activity;
  final String? stack;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'ms': duration.inMilliseconds,
    'activity': activity.name,
    'stack': ?stack,
  };
}

class LoopStats {
  final _samples = ListQueue<int>();
  static const keep = 240;
  int worstMicros = 0;

  void add(int lateMicros) {
    _samples.add(lateMicros);
    while (_samples.length > keep) {
      _samples.removeFirst();
    }
    if (lateMicros > worstMicros) worstMicros = lateMicros;
  }

  Map<String, double> summary() {
    if (_samples.isEmpty) return const {'p50_ms': 0, 'p99_ms': 0, 'max_ms': 0};
    final sorted = [..._samples]..sort();
    double at(double q) => sorted[(q * (sorted.length - 1)).round()] / 1000;
    return {'p50_ms': at(0.5), 'p99_ms': at(0.99), 'max_ms': sorted.last / 1000};
  }
}

class Watchdog {
  new({
    this.threshold = const Duration(seconds: 2),
    this.beat = const Duration(milliseconds: 250),
    this.onStall,
    this.keepStalls = 50,
  });

  static Watchdog? current;

  static void activity(Activity value) {
    final memory = current?._memory;
    if (memory == null) return;
    memory[1] = value.index;
    memory[2] = DateTime.now().microsecondsSinceEpoch;
  }

  static T during<T>(Activity value, T Function() body) {
    final memory = current?._memory;
    if (memory == null) return body();
    final previous = memory[1];
    activity(value);
    try {
      return body();
    } finally {
      memory[1] = previous;
    }
  }

  final Duration threshold;
  final Duration beat;
  final void Function(Stall stall)? onStall;
  final int keepStalls;

  final loop = LoopStats();
  final stalls = ListQueue<Stall>();
  Pointer<Int64>? _pointer;
  Int64List? _memory;
  Isolate? _isolate;
  ReceivePort? _port;
  Timer? _timer;
  final _clock = Stopwatch();
  int _expected = 0;

  bool get running => _isolate != null;

  Future<void> start({String? serviceUri, String? isolateId}) async {
    if (_isolate != null) return;
    final pointer = Native.malloc(8 * 8).cast<Int64>();
    final memory = pointer.asTypedList(8)..fillRange(0, 8, 0);
    memory[0] = DateTime.now().microsecondsSinceEpoch;
    _pointer = pointer;
    _memory = memory;
    current = this;
    _clock.start();
    _expected = beat.inMicroseconds;
    _timer = Timer.periodic(beat, (_) {
      final elapsed = _clock.elapsedMicroseconds;
      loop.add((elapsed - _expected).clamp(0, 1 << 40));
      _clock
        ..reset()
        ..start();
      memory[0] = DateTime.now().microsecondsSinceEpoch;
    });
    final port = ReceivePort('watchdog');
    _port = port;
    port.listen((Object? message) {
      if (message is! String) return;
      final stall = Stall.fromJson((jsonDecode(message) as Map).cast<String, Object?>());
      stalls.addFirst(stall);
      while (stalls.length > keepStalls) {
        stalls.removeLast();
      }
      onStall?.call(stall);
    });
    _isolate = await Isolate.spawn(
      _watch,
      (pointer.address, port.sendPort, threshold.inMicroseconds, serviceUri, isolateId),
      debugName: 'watchdog',
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
    if (identical(current, this)) current = null;
    _memory = null;
    final pointer = _pointer;
    _pointer = null;
    if (pointer != null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Native.free(pointer.cast());
    }
  }

  static void _watch((int, SendPort, int, String?, String?) args) {
    final (address, reply, threshold, serviceUri, isolateId) = args;
    final memory = Pointer<Int64>.fromAddress(address).asTypedList(8);
    final tick = Stopwatch()..start();
    var stallStart = 0;
    var stallActivity = 0;
    String? stack;
    var capturing = false;
    Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final ownGap = tick.elapsedMicroseconds;
      tick
        ..reset()
        ..start();
      final now = DateTime.now().microsecondsSinceEpoch;
      final heartbeat = memory[0];
      if (ownGap > threshold) {
        stallStart = 0;
        return;
      }
      final silent = now - heartbeat;
      if (stallStart == 0 && silent > threshold) {
        stallStart = heartbeat;
        stallActivity = memory[1];
        stack = null;
        if (serviceUri != null && isolateId != null && !capturing) {
          capturing = true;
          stack = await _captureStack(serviceUri, isolateId);
          capturing = false;
        }
      } else if (stallStart != 0 && silent < threshold ~/ 4) {
        final stall = Stall(
          at: DateTime.fromMicrosecondsSinceEpoch(stallStart),
          duration: Duration(microseconds: heartbeat - stallStart),
          activity: Activity.values[stallActivity.clamp(0, Activity.values.length - 1)],
          stack: stack,
        );
        stallStart = 0;
        reply.send(jsonEncode(stall.toJson()));
      }
    });
  }

  static Future<String?> _captureStack(String serviceUri, String isolateId) async {
    WebSocket? socket;
    try {
      final uri = Uri.parse(serviceUri);
      final ws = uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws', path: '${uri.path.endsWith('/') ? uri.path : '${uri.path}/'}ws');
      socket = await WebSocket.connect(ws.toString()).timeout(const Duration(seconds: 2));
      socket.add(jsonEncode({'jsonrpc': '2.0', 'id': '1', 'method': 'getStack', 'params': {'isolateId': isolateId, 'limit': 30}}));
      final reply = await socket.first.timeout(const Duration(seconds: 3));
      final result = ((jsonDecode('$reply') as Map)['result'] as Map?) ?? const {};
      final frames = (result['frames'] as List?) ?? const [];
      return [
        for (final frame in frames.cast<Map<String, Object?>>())
          () {
            final code = (frame['code'] as Map?) ?? const {};
            final location = (frame['location'] as Map?) ?? const {};
            final script = (location['script'] as Map?) ?? const {};
            return '${code['name'] ?? '?'} (${script['uri'] ?? '?'})';
          }(),
      ].join('\n');
    } on Object {
      return null;
    } finally {
      await socket?.close();
    }
  }
}
