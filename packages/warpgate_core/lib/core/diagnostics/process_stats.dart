import 'dart:ffi';
import 'dart:io';

import 'package:warpgate_core/core/platform/native.dart';

typedef _RusageNative = Int32 Function(Int32, Pointer<Uint8>);
typedef _Rusage = int Function(int, Pointer<Uint8>);
typedef _CurrentProcessNative = IntPtr Function();
typedef _CurrentProcess = int Function();
typedef _TimesNative = Int32 Function(IntPtr, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>);
typedef _Times = int Function(int, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>);

class CpuMeter {
  Duration? _lastCpu;
  DateTime? _lastAt;
  double percent = 0;

  double sample() {
    final cpu = ProcessStats.cpuTime();
    final now = DateTime.now();
    final lastCpu = _lastCpu;
    final lastAt = _lastAt;
    _lastCpu = cpu;
    _lastAt = now;
    if (cpu == null || lastCpu == null || lastAt == null) return percent;
    final wall = now.difference(lastAt).inMicroseconds;
    if (wall <= 0) return percent;
    return percent = (cpu - lastCpu).inMicroseconds * 100 / wall;
  }
}

abstract final class ProcessStats {
  static int get rss => ProcessInfo.currentRss;

  static int get maxRss => ProcessInfo.maxRss;

  static _Rusage? _rusage;
  static (_CurrentProcess, _Times)? _windows;

  static Duration? cpuTime() {
    try {
      if (Platform.isWindows) return _windowsCpu();
      if (Platform.isMacOS || Platform.isLinux || Platform.isAndroid || Platform.isIOS) {
        return _posixCpu();
      }
    } on Object {
      return null;
    }
    return null;
  }

  static Duration _posixCpu() {
    final call = _rusage ??= DynamicLibrary.process().lookupFunction<_RusageNative, _Rusage>('getrusage');
    final buffer = Native.malloc(256).cast<Uint8>();
    try {
      buffer.asTypedList(256).fillRange(0, 256, 0);
      call(0, buffer);
      final data = buffer.cast<Int64>().asTypedList(4);
      final words = buffer.cast<Int32>().asTypedList(8);
      final userMicros = data[0] * 1000000 + words[2];
      final systemMicros = data[2] * 1000000 + words[6];
      return Duration(microseconds: userMicros + systemMicros);
    } finally {
      Native.free(buffer.cast());
    }
  }

  static Duration _windowsCpu() {
    final (current, times) = _windows ??= () {
      final kernel = DynamicLibrary.open('kernel32.dll');
      return (
        kernel.lookupFunction<_CurrentProcessNative, _CurrentProcess>('GetCurrentProcess'),
        kernel.lookupFunction<_TimesNative, _Times>('GetProcessTimes'),
      );
    }();
    final buffer = Native.malloc(32).cast<Uint64>();
    try {
      times(current(), buffer, buffer + 1, buffer + 2, buffer + 3);
      final values = buffer.asTypedList(4);
      return Duration(microseconds: (values[2] + values[3]) ~/ 10);
    } finally {
      Native.free(buffer.cast());
    }
  }
}
