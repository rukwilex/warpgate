import 'dart:ffi';
import 'dart:io';

import 'package:warpgate_core/core/platform/native.dart';

typedef _TcGetNative = Int32 Function(Int32, Pointer<Void>);
typedef _TcGet = int Function(int, Pointer<Void>);
typedef _TcSetNative = Int32 Function(Int32, Int32, Pointer<Void>);
typedef _TcSet = int Function(int, int, Pointer<Void>);
typedef _MakeRawNative = Void Function(Pointer<Void>);
typedef _MakeRaw = void Function(Pointer<Void>);

class RawTerminal {
  Pointer<Void>? _saved;
  bool? _echo;
  bool? _line;

  void enter() {
    if (!stdin.hasTerminal) return;
    if (Platform.isWindows) {
      _echo = stdin.echoMode;
      _line = stdin.lineMode;
      stdin
        ..echoMode = false
        ..lineMode = false;
      return;
    }
    final libc = DynamicLibrary.process();
    final get = libc.lookupFunction<_TcGetNative, _TcGet>('tcgetattr');
    final set = libc.lookupFunction<_TcSetNative, _TcSet>('tcsetattr');
    final makeRaw = libc.lookupFunction<_MakeRawNative, _MakeRaw>('cfmakeraw');
    final saved = Native.malloc(256);
    final raw = Native.malloc(256);
    if (get(0, saved) != 0) {
      Native.free(saved);
      Native.free(raw);
      return;
    }
    get(0, raw);
    makeRaw(raw);
    set(0, 0, raw);
    Native.free(raw);
    _saved = saved;
  }

  void leave() {
    if (Platform.isWindows) {
      final echo = _echo;
      final line = _line;
      if (echo != null && line != null) {
        stdin
          ..lineMode = line
          ..echoMode = echo;
      }
      _echo = null;
      _line = null;
      return;
    }
    final saved = _saved;
    if (saved == null) return;
    final libc = DynamicLibrary.process();
    libc.lookupFunction<_TcSetNative, _TcSet>('tcsetattr')(0, 0, saved);
    Native.free(saved);
    _saved = null;
  }
}
