import 'dart:ffi';
import 'dart:io';

typedef _ChmodNative = Int32 Function(Pointer<Uint8>, Uint32);
typedef _Chmod = int Function(Pointer<Uint8>, int);
typedef _KillNative = Int32 Function(Int32, Int32);
typedef _Kill = int Function(int, int);
typedef MallocNative = Pointer<Void> Function(IntPtr);
typedef MallocFn = Pointer<Void> Function(int);
typedef FreeNative = Void Function(Pointer<Void>);
typedef FreeFn = void Function(Pointer<Void>);

abstract final class Native {
  static final DynamicLibrary _libc = Platform.isWindows
      ? DynamicLibrary.open('ucrtbase.dll')
      : DynamicLibrary.process();

  static final MallocFn malloc = _libc.lookupFunction<MallocNative, MallocFn>(
    'malloc',
  );
  static final FreeFn free = _libc.lookupFunction<FreeNative, FreeFn>('free');

  static Pointer<Uint8> cString(List<int> bytes) {
    final pointer = malloc(bytes.length + 1).cast<Uint8>();
    pointer.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    return pointer;
  }

  static void chmod(String path, int mode) {
    if (Platform.isWindows) return;
    final call = _libc.lookupFunction<_ChmodNative, _Chmod>('chmod');
    final name = cString(path.codeUnits);
    call(name, mode);
    free(name.cast());
  }

  static int? modeOf(String path) {
    if (Platform.isWindows) return null;
    final stat = FileStat.statSync(path);
    return stat.type == FileSystemEntityType.notFound ? null : stat.mode & 0xFFF;
  }

  static bool signalGroup(int processGroup, int signal) {
    if (Platform.isWindows || processGroup <= 0) return false;
    final call = _libc.lookupFunction<_KillNative, _Kill>('kill');
    return call(-processGroup, signal) == 0;
  }

  static bool isProcessAlive(int processId) {
    if (Platform.isWindows) {
      final result = Process.runSync('tasklist', [
        '/FI',
        'PID eq $processId',
        '/NH',
      ]);
      return result.stdout.toString().contains('$processId');
    }
    final call = _libc.lookupFunction<_KillNative, _Kill>('kill');
    return call(processId, 0) == 0;
  }
}
