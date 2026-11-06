import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_pty/src/flutter_pty_bindings_generated.dart';

const _libName = 'flutter_pty';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final _bindings = FlutterPtyBindings(_dylib);

final _init = () {
  return _bindings.Dart_InitializeApiDL(NativeApi.initializeApiDLData);
}();

void _ensureInitialized() {
  if (_init != 0) {
    throw StateError('Failed to initialize native bindings');
  }
}

class Pty {
  final String executable;

  final List<String> arguments;

  Pty.start(
    this.executable, {
    this.arguments = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    int rows = 25,
    int columns = 80,
    bool ackRead = false,
  }) {
    _ensureInitialized();

    final effectiveEnv = <String, String>{};

    effectiveEnv['TERM'] = 'xterm-256color';

    effectiveEnv['LANG'] = 'en_US.UTF-8';

    const envValuesToCopy = {
      'LOGNAME',
      'USER',
      'DISPLAY',
      'LC_TYPE',
      'HOME',
      'PATH'
    };

    for (var entry in Platform.environment.entries) {
      if (envValuesToCopy.contains(entry.key)) {
        effectiveEnv[entry.key] = entry.value;
      }
    }

    if (environment != null) {
      for (var entry in environment.entries) {
        effectiveEnv[entry.key] = entry.value;
      }
    }

    final argv = calloc<Pointer<Utf8>>(arguments.length + 2);
    argv.elementAt(0).value = executable.toNativeUtf8();
    for (var i = 0; i < arguments.length; i++) {
      argv.elementAt(i + 1).value = arguments[i].toNativeUtf8();
    }
    argv.elementAt(arguments.length + 1).value = nullptr;

    final envp = calloc<Pointer<Utf8>>(effectiveEnv.length + 1);
    for (var i = 0; i < effectiveEnv.length; i++) {
      final entry = effectiveEnv.entries.elementAt(i);
      envp.elementAt(i).value = '${entry.key}=${entry.value}'.toNativeUtf8();
    }
    envp.elementAt(effectiveEnv.length).value = nullptr;

    final options = calloc<PtyOptions>();
    options.ref.rows = rows;
    options.ref.cols = columns;
    options.ref.executable = executable.toNativeUtf8().cast();
    options.ref.arguments = argv.cast();
    options.ref.environment = envp.cast();
    options.ref.stdout_port = _stdoutPort.sendPort.nativePort;
    options.ref.exit_port = _exitPort.sendPort.nativePort;
    options.ref.ackRead = ackRead;

    if (workingDirectory != null) {
      options.ref.working_directory = workingDirectory.toNativeUtf8().cast();
    } else {
      options.ref.working_directory = nullptr;
    }

    _handle = _bindings.pty_create(options);

    calloc.free(options);

    if (_handle == nullptr) {
      throw StateError('Failed to create PTY: ${_getPtyError()}');
    }

    _exitPort.first.then(_onExitCode);
  }

  final _stdoutPort = ReceivePort();

  final _exitPort = ReceivePort();

  final _exitCodeCompleter = Completer<int>();

  late final Pointer<PtyHandle> _handle;

  Stream<Uint8List> get output => _stdoutPort.cast();

  Future<int> get exitCode => _exitCodeCompleter.future;

  int get pid => _bindings.pty_getpid(_handle);

  void write(Uint8List data) {
    if (_closed) return;
    final buf = malloc<Int8>(data.length);
    buf.asTypedList(data.length).setAll(0, data);
    _bindings.pty_write(_handle, buf.cast(), data.length);
    malloc.free(buf);
  }

  void resize(int rows, int cols) {
    if (_closed) return;
    _bindings.pty_resize(_handle, rows, cols);
  }

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return Process.killPid(pid, signal);
  }

  void ackRead() {
    if (_closed) return;
    _bindings.pty_ack_read(_handle);
  }

  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _bindings.pty_close(_handle);
  }

  void _onExitCode(dynamic exitCode) {
    _stdoutPort.close();
    _exitPort.close();
    _exitCodeCompleter.complete(exitCode);
  }
}

String? _getPtyError() {
  final error = _bindings.pty_error();

  if (error == nullptr) {
    return null;
  }

  return error.cast<Utf8>().toDartString();
}
