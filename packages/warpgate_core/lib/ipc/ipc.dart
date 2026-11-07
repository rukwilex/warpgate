import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/core/platform/native.dart';

abstract final class IpcProtocol {
  static const version = 1;
}

abstract final class AppInstance {
  static Future<bool> isRunning(AppPaths paths) async {
    final file = File(paths.ipcLock);
    if (!file.existsSync()) return false;
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock();
      await handle.unlock();
      return false;
    } on FileSystemException {
      return true;
    } finally {
      await handle.close();
    }
  }
}

class IpcUnavailable implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef IpcHandler = Future<JsonMap> Function(String method, JsonMap params);

class IpcServer {
  new(this.paths, this.handler);

  final AppPaths paths;
  final IpcHandler handler;
  ServerSocket? _server;
  RandomAccessFile? _lock;
  final _clients = <Socket>{};
  String? _token;

  static String _newToken() {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<void> start() async {
    final directory = Directory(paths.ipcDirectory);
    await directory.create(recursive: true);
    Native.chmod(directory.path, 448);
    final lock = await File(paths.ipcLock).open(mode: FileMode.append);
    try {
      await lock.lock();
    } on FileSystemException {
      await lock.close();
      throw const IpcUnavailable('Another copy of Warpgate is using this profile');
    }
    _lock = lock;
    try {
      await _bind();
    } on Object {
      await stop();
      rethrow;
    }
  }

  Future<void> _bind() async {
    final socketPath = paths.ipcSocket;
    if (!Platform.isWindows && socketPath.length > AppPaths.maxSocketPath) {
      throw IpcUnavailable(
        'The socket path is too long for this system: $socketPath',
      );
    }
    final token = _newToken();
    _token = token;
    final tokenFile = File(paths.ipcToken);
    await tokenFile.writeAsString('');
    Native.chmod(tokenFile.path, 384);
    await tokenFile.writeAsString(token, flush: true);
    if (Platform.isWindows) {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      await File(paths.ipcPort).writeAsString('${server.port}', flush: true);
    } else {
      final socket = File(socketPath);
      if (socket.existsSync() || FileSystemEntity.typeSync(socketPath) != FileSystemEntityType.notFound) {
        await socket.delete();
      }
      _server = await ServerSocket.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      Native.chmod(socketPath, 384);
    }
    _server!.listen(_accept);
  }

  void _accept(Socket socket) {
    _clients.add(socket);
    var authed = false;
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => unawaited(() async {
            final message = (jsonDecode(line) as Map).cast<String, Object?>();
            if (!authed) {
              authed = _matches(message['hello'] as String?);
              socket.writeln(jsonEncode({'hello': authed}));
              if (!authed) await socket.close();
              return;
            }
            final id = message['id'];
            try {
              final result = await handler(
                message['method']! as String,
                ((message['params'] as Map?) ?? const {}).cast<String, Object?>(),
              );
              socket.writeln(jsonEncode({'id': id, 'result': result}));
            } on ActionFailure catch (failure) {
              socket.writeln(
                jsonEncode({
                  'id': id,
                  'error': {
                    'kind': failure.kind.name,
                    'message': failure.message,
                    'hint': failure.hint,
                  },
                }),
              );
            } on Object catch (error) {
              socket.writeln(
                jsonEncode({
                  'id': id,
                  'error': {'kind': 'general', 'message': error.toString()},
                }),
              );
            }
          }()),
          onDone: () => _clients.remove(socket),
          onError: (Object _) => _clients.remove(socket),
          cancelOnError: true,
        );
  }

  bool _matches(String? candidate) {
    final token = _token;
    if (candidate == null || token == null) return false;
    if (candidate.length != token.length) return false;
    var difference = 0;
    for (var i = 0; i < token.length; i++) {
      difference |= candidate.codeUnitAt(i) ^ token.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> stop() async {
    for (final client in _clients.toList()) {
      client.destroy();
    }
    await _server?.close();
    _server = null;
    final lock = _lock;
    if (lock == null) return;
    for (final path in [paths.ipcToken, paths.ipcSocket, paths.ipcPort]) {
      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound) {
        await File(path).delete();
      }
    }
    await lock.unlock();
    await lock.close();
    _lock = null;
  }
}

class IpcClient {
  IpcClient._(this._socket, this._lines);

  final Socket _socket;
  final StreamIterator<String> _lines;
  int _next = 0;
  Future<void> _tail = Future.value();

  static Future<IpcClient?> connect(
    AppPaths paths, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    final tokenFile = File(paths.ipcToken);
    if (!tokenFile.existsSync()) return null;
    try {
      final Socket socket;
      if (Platform.isWindows) {
        final port = int.parse(File(paths.ipcPort).readAsStringSync().trim());
        socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: timeout,
        );
      } else {
        socket = await Socket.connect(
          InternetAddress(paths.ipcSocket, type: InternetAddressType.unix),
          0,
          timeout: timeout,
        );
      }
      final lines = StreamIterator(
        socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );
      socket.writeln(
        jsonEncode({
          'hello': tokenFile.readAsStringSync().trim(),
          'version': IpcProtocol.version,
        }),
      );
      if (!await lines.moveNext().timeout(timeout)) return null;
      final reply = (jsonDecode(lines.current) as Map).cast<String, Object?>();
      if (reply['hello'] != true) {
        socket.destroy();
        return null;
      }
      final client = IpcClient._(socket, lines);
      unawaited(socket.done.then<void>((_) => client._broken = true, onError: (Object _) => client._broken = true));
      return client;
    } on Object {
      return null;
    }
  }

  static Duration defaultTimeout = const Duration(seconds: 60);
  bool _broken = false;

  Future<JsonMap> call(
    String method, [
    JsonMap params = const {},
    Duration? timeout,
  ]) {
    final done = Completer<JsonMap>();
    _tail = _tail.then((_) async {
      if (_broken) {
        done.completeError(const IpcUnavailable('The connection to Warpgate was lost'));
        return;
      }
      try {
        done.complete(await _send(method, params).timeout(timeout ?? defaultTimeout));
      } on TimeoutException {
        _broken = true;
        _socket.destroy();
        done.completeError(const IpcUnavailable('Warpgate did not answer in time'));
      } on Object catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  Future<JsonMap> _send(String method, JsonMap params) async {
    final id = _next++;
    try {
      _socket.writeln(jsonEncode({'id': id, 'method': method, 'params': params}));
    } on Object {
      _broken = true;
      throw const IpcUnavailable('The connection to Warpgate was lost');
    }
    late Map<String, Object?> reply;
    do {
      if (!await _lines.moveNext()) {
        _broken = true;
        throw const IpcUnavailable('Warpgate closed the connection');
      }
      reply = (jsonDecode(_lines.current) as Map).cast<String, Object?>();
    } while (reply.containsKey('id') && reply['id'] != id);
    final error = reply['error'];
    if (error is Map) {
      throw ActionFailure(
        error['message'] as String? ?? 'The app reported an error',
        kind: ExitKind.values.asNameMap()[error['kind']] ?? ExitKind.general,
        hint: error['hint'] as String?,
      );
    }
    return ((reply['result'] as Map?) ?? const {}).cast<String, Object?>();
  }

  Future<void> close() async => _socket.destroy();
}
