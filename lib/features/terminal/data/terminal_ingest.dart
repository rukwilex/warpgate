import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:warpgate_core/core/diagnostics/watchdog.dart';

abstract class IngestSink {
  bool _listed = false;

  bool drainSome(int maxBytes);
}

class IngestQueue {
  new({
    required this.write,
    required this.onLow,
    required this.onHigh,
    this.highWater = 1 << 20,
    this.lowWater = 256 << 10,
  });

  final void Function(String text) write;
  final void Function() onLow;
  final void Function() onHigh;
  final int highWater;
  final int lowWater;

  final _chunks = ListQueue<Uint8List>();
  int _offset = 0;
  int _bytes = 0;
  bool _throttled = false;
  int peakBytes = 0;

  late final ByteConversionSink _sink = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(_TextSink(write));

  int get pendingBytes => _bytes;

  bool get isEmpty => _bytes == 0;

  bool get throttled => _throttled;

  void add(Uint8List data) {
    if (data.isEmpty) return;
    _chunks.add(data);
    _bytes += data.length;
    if (_bytes > peakBytes) peakBytes = _bytes;
    if (!_throttled && _bytes >= highWater) {
      _throttled = true;
      onHigh();
    }
  }

  int take(int maxBytes) {
    var taken = 0;
    while (taken < maxBytes && _chunks.isNotEmpty) {
      final head = _chunks.first;
      final available = head.length - _offset;
      final count = available <= maxBytes - taken
          ? available
          : maxBytes - taken;
      _sink.add(Uint8List.sublistView(head, _offset, _offset + count));
      taken += count;
      _offset += count;
      if (_offset == head.length) {
        _chunks.removeFirst();
        _offset = 0;
      }
    }
    _bytes -= taken;
    if (_throttled && _bytes <= lowWater) {
      _throttled = false;
      onLow();
    }
    return taken;
  }

  void flush() {
    while (_bytes > 0) {
      take(1 << 20);
    }
  }

  void clear() {
    _chunks.clear();
    _offset = 0;
    _bytes = 0;
    if (_throttled) {
      _throttled = false;
      onLow();
    }
  }
}

class _TextSink implements Sink<String> {
  new(this._write);

  final void Function(String text) _write;

  @override
  void add(String data) {
    if (data.isNotEmpty) _write(data);
  }

  @override
  void close() {}
}

class TerminalIngest {
  new _();

  static final TerminalIngest instance = TerminalIngest._();

  static Duration budget = const Duration(milliseconds: 8);
  static Duration yieldFor = const Duration(milliseconds: 4);
  static const int slice = 16 * 1024;

  final ListQueue<IngestSink> _ready = ListQueue<IngestSink>();
  Timer? _timer;
  int runs = 0;
  int yields = 0;
  int longestRunMicros = 0;

  int get waiting => _ready.length;

  void notify(IngestSink sink) {
    if (!sink._listed) {
      sink._listed = true;
      _ready.add(sink);
    }
    _timer ??= Timer(Duration.zero, _run);
  }

  void forget(IngestSink sink) {
    if (sink._listed) {
      sink._listed = false;
      _ready.remove(sink);
    }
  }

  void _run() {
    _timer = null;
    runs++;
    final watch = Stopwatch()..start();
    final limit = budget.inMicroseconds;
    Watchdog.activity(Activity.terminalIngest);
    while (_ready.isNotEmpty && watch.elapsedMicroseconds < limit) {
      final sink = _ready.removeFirst().._listed = false;
      if (sink.drainSome(slice)) {
        sink._listed = true;
        _ready.add(sink);
      }
    }
    Watchdog.activity(Activity.idle);
    final spent = watch.elapsedMicroseconds;
    if (spent > longestRunMicros) longestRunMicros = spent;
    if (_ready.isNotEmpty) {
      yields++;
      _timer = Timer(yieldFor, _run);
    }
  }
}
