import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/src/engine/api/sftp.dart' as rs;
import 'package:warpgate_core/src/engine/api/ssh.dart' as rs;
import 'package:warpgate_core/src/engine/api/util.dart' as rs;
import 'package:warpgate_core/src/engine/frb_generated.dart';

enum SshEngineKind { native, dart }

abstract final class NativeEngine {
  static SshEngineKind preferred = SshEngineKind.native;
  static Future<bool>? _loading;
  static bool _available = false;
  static String? loadError;

  static bool get available => _available;

  static bool get active => _available && preferred == SshEngineKind.native;

  static List<String> candidates() {
    final override = Platform.environment['WARPGATE_ENGINE_LIBRARY'];
    final executable = p.dirname(Platform.resolvedExecutable);
    final name = Platform.isWindows
        ? 'warpgate_engine.dll'
        : Platform.isMacOS
        ? 'libwarpgate_engine.dylib'
        : 'libwarpgate_engine.so';
    return [
      ?override,
      p.join(executable, name),
      p.join(executable, 'lib', name),
      p.join(
        executable,
        '..',
        'Frameworks',
        'warpgate_engine.framework',
        'warpgate_engine',
      ),
      p.join(executable, '..', 'Frameworks', name),
      if (Platform.isMacOS || Platform.isIOS)
        'warpgate_engine.framework/warpgate_engine',
      name,
    ];
  }

  static Future<bool> ensureLoaded() => _loading ??= _load();

  static Future<bool> _load() async {
    if (Platform.environment['WARPGATE_ENGINE'] == 'dart') {
      preferred = SshEngineKind.dart;
      return false;
    }
    final errors = <String>[];
    if (Platform.isMacOS || Platform.isIOS) {
      try {
        await WarpgateEngine.init(externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true));
        _available = true;
        return true;
      } on Object catch (error) {
        errors.add('process: $error');
      }
    }
    for (final candidate in candidates()) {
      final absolute = p.isAbsolute(candidate);
      if (absolute && !File(candidate).existsSync()) continue;
      try {
        await WarpgateEngine.init(
          externalLibrary: ExternalLibrary.open(candidate),
        );
        _available = true;
        return true;
      } on Object catch (error) {
        errors.add('$candidate: $error');
      }
    }
    loadError = errors.isEmpty
        ? 'The engine library was not found'
        : errors.join('; ');
    return false;
  }

  static String? get version => _available ? rs.engineVersion() : null;

  static Future<String?> sha256File(String path) async {
    if (!await ensureLoaded()) return null;
    return rs.sha256File(path: path);
  }
}

Object nativeError(Object error) {
  final text = error is AnyhowException ? error.message : '$error';
  final colon = text.indexOf(':');
  final kind = colon < 0 ? '' : text.substring(0, colon).trim();
  final message = colon < 0 ? text : text.substring(colon + 1).trim();
  return switch (kind) {
    'hostkey' => SSHHostkeyError(message),
    'auth' => SSHAuthFailError(message),
    'auth_abort' => SSHAuthAbortError(message),
    'key_decrypt' => SSHKeyDecryptError(message),
    'key_decode' => SSHKeyDecodeError(message),
    'timeout' => TimeoutException(message),
    'socket' => SSHSocketError(SocketException(message)),
    'handshake' => SSHHandshakeError(message),
    'channel' || 'channel_request' => SSHChannelOpenError(2, message),
    'cancelled' => SSHAuthAbortError(message),
    _ when kind.startsWith('sftp_status') => SftpStatusError(
      int.tryParse(kind.split(' ').last) ?? 4,
      message,
    ),
    _ => SSHStateError(text),
  };
}

Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on AnyhowException catch (error) {
    throw nativeError(error);
  }
}

sealed class NativeCredential {
  const NativeCredential();
}

class AgentCredential extends NativeCredential {
  const AgentCredential(this.socket);

  final String? socket;
}

class KeyCredential extends NativeCredential {
  const KeyCredential(this.pem, this.passphrase);

  final String pem;
  final String? passphrase;
}

class NativeAuth {
  const NativeAuth({
    required this.username,
    this.credentials = const [],
    this.password,
    this.keyboardInteractive,
  });

  final String username;
  final List<NativeCredential> credentials;
  final Future<String?> Function()? password;
  final Future<List<String>?> Function(SSHUserInfoRequest request)?
  keyboardInteractive;
}

class NativeSshClient implements SSHClient {
  NativeSshClient._(this._client, this.username) {
    LiveObjects.opened('native ssh client');
    unawaited(
      _client.waitClosed().then<void>(
        (_) => _finish(null),
        onError: (Object error) => _finish(error),
      ),
    );
  }

  static Future<NativeSshClient> connect({
    required String host,
    required int port,
    required NativeAuth auth,
    required Future<bool> Function(String type, String fingerprint) verify,
    NativeSshClient? jump,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration handshakeTimeout = const Duration(seconds: 15),
    String clientId = 'SSH-2.0-Warpgate_1.0',
  }) async {
    final params = rs.ConnectParams(
      host: host,
      port: port,
      connectTimeoutMs: connectTimeout.inMilliseconds,
      handshakeTimeoutMs: handshakeTimeout.inMilliseconds,
      clientId: clientId,
    );
    final cancel = rs.CancelToken();
    final client = await _guard(
      () => jump == null
          ? rs.connect(params: params, cancel: cancel, verifier: verify)
          : jump._client.connectVia(params: params, verifier: verify),
    );
    final wrapped = NativeSshClient._(client, auth.username);
    try {
      await wrapped._authenticate(auth);
    } on Object {
      wrapped.close();
      rethrow;
    }
    return wrapped;
  }

  final rs.SshClient _client;
  @override
  final String username;
  final _done = Completer<void>();
  final _authenticated = Completer<void>();
  bool _closed = false;

  Future<void> _authenticate(NativeAuth auth) async {
    final user = auth.username;
    for (final credential in auth.credentials) {
      final ok = await _guard(
        () => switch (credential) {
          AgentCredential(:final socket) =>
            _client
                .authAgent(user: user, socket: socket)
                .catchError((_) => false),
          KeyCredential(:final pem, :final passphrase) => _client.authKey(
            user: user,
            pem: pem,
            passphrase: passphrase,
          ),
        },
      );
      if (ok) return _authenticated.complete();
    }
    final password = auth.password;
    if (password != null) {
      final value = await password();
      if (value != null &&
          await _guard(
            () => _client.authPassword(user: user, password: value),
          )) {
        return _authenticated.complete();
      }
    }
    final interactive = auth.keyboardInteractive;
    if (interactive != null) {
      final ok = await _guard(
        () => _client.authKeyboardInteractive(
          user: user,
          responder: (name, instruction, prompts, echoes) => interactive(
            SSHUserInfoRequest(name, instruction, [
              for (var i = 0; i < prompts.length; i++)
                SSHUserInfoPrompt(prompts[i], echoes[i]),
            ]),
          ),
        ),
      );
      if (ok) return _authenticated.complete();
    }
    throw SSHAuthFailError('All authentication methods failed');
  }

  void _finish(Object? error) {
    if (_done.isCompleted) return;
    _closed = true;
    LiveObjects.closed('native ssh client');
    if (error == null || _closed) {
      _done.complete();
    } else {
      _done.completeError(error);
    }
  }

  @override
  Future<void> get authenticated => _authenticated.future;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => _closed || _client.isClosed();

  @override
  Future<void> ping() => _guard(() => _client.ping(timeoutMs: 15000));

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _client.disconnect();
    } on Object {
      return;
    }
  }

  Future<NativeSshSession> _session({
    String? command,
    SSHPtyConfig? pty,
    Map<String, String>? environment,
  }) async {
    final channel = await _guard(_client.openSession);
    try {
      if (pty != null) {
        await _guard(
          () => channel.requestPty(
            term: pty.type,
            columns: pty.width,
            rows: pty.height,
          ),
        );
      }
      for (final MapEntry(:key, :value)
          in (environment ?? const <String, String>{}).entries) {
        try {
          await channel.setEnv(name: key, value: value);
        } on Object {
          continue;
        }
      }
      if (command == null) {
        await _guard(channel.requestShell);
      } else {
        await _guard(() => channel.exec(command: command));
      }
    } on Object {
      unawaited(channel.close().catchError((_) {}));
      rethrow;
    }
    return NativeSshSession(channel);
  }

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty = const SSHPtyConfig(),
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    return _session(pty: pty, environment: environment);
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) => _session(command: command, pty: pty, environment: environment);

  @override
  Future<SftpClient> sftp() async =>
      NativeSftpClient(await _guard(_client.sftp));

  @override
  Future<SSHForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) async => NativeForwardChannel(
    await _guard(
      () => _client.openDirectTcpip(host: remoteHost, port: remotePort),
    ),
  );

  @override
  Future<SSHDynamicForward> forwardDynamic({
    String bindHost = '127.0.0.1',
    int? bindPort,
    SSHDynamicForwardOptions options = const SSHDynamicForwardOptions(),
    SSHDynamicConnectionFilter? filter,
  }) => startDynamicForward(
    bindHost: bindHost,
    bindPort: bindPort,
    options: options,
    filter: filter,
    dial: forwardLocal,
  );

  final List<NativeRemoteForward> _remotes = [];
  bool _accepting = false;

  @override
  Future<SSHRemoteForward?> forwardRemote({
    String? host,
    int? port,
    SSHRemoteConnectionFilter? filter,
  }) async {
    final bindHost = host ?? 'localhost';
    try {
      final assigned = await _guard(
        () => _client.forwardRemote(host: bindHost, port: port ?? 0),
      );
      final forward = NativeRemoteForward(this, bindHost, assigned, filter);
      _remotes.add(forward);
      if (!_accepting) unawaited(_accept());
      return forward;
    } on Object {
      return null;
    }
  }

  Future<void> _accept() async {
    _accepting = true;
    try {
      while (!isClosed && _remotes.isNotEmpty) {
        final next = await _client.acceptForwarded();
        if (next == null) break;
        final target =
            _remotes.where((r) => r.port == next.connectedPort).firstOrNull ??
            _remotes.firstOrNull;
        final channel = NativeForwardChannel(next.channel);
        if (target == null ||
            (target.filter != null &&
                !target.filter!(next.originHost, next.originPort))) {
          unawaited(channel.close());
          continue;
        }
        target._connections.add(channel);
      }
    } on Object {
      return;
    } finally {
      _accepting = false;
    }
  }

  @override
  Future<bool> cancelForwardRemote(SSHRemoteForward forward) async {
    _remotes.remove(forward);
    if (forward is NativeRemoteForward) unawaited(forward._connections.close());
    try {
      await _client.cancelForwardRemote(host: forward.host, port: forward.port);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}

class NativeRemoteForward implements SSHRemoteForward {
  NativeRemoteForward(this._owner, this.host, this.port, this.filter);

  final NativeSshClient _owner;
  @override
  final String host;
  @override
  final int port;
  @override
  final SSHRemoteConnectionFilter? filter;
  final _connections = StreamController<SSHForwardChannel>();

  @override
  Stream<SSHForwardChannel> get connections => _connections.stream;

  NativeSshClient get owner => _owner;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}

class _ChannelPump {
  _ChannelPump(
    this.channel, {
    required this.onData,
    required this.onExtended,
    required this.onClosed,
  });

  static const chunk = 256 * 1024;

  final rs.SshChannel channel;
  final void Function(Uint8List data) onData;
  final void Function(Uint8List data) onExtended;
  final void Function() onClosed;
  bool _running = false;
  bool _stopped = false;
  bool paused = false;
  Completer<void>? _resume;

  void start() {
    if (_running || _stopped) return;
    _running = true;
    unawaited(_loop());
  }

  void pause() => paused = true;

  void resume() {
    paused = false;
    _resume?.complete();
    _resume = null;
  }

  void stop() {
    _stopped = true;
    resume();
  }

  Future<void> _loop() async {
    try {
      while (!_stopped) {
        if (paused) {
          await (_resume ??= Completer<void>()).future;
          continue;
        }
        final next = await channel.read(maxBytes: chunk);
        if (next.data.isNotEmpty) onData(next.data);
        if (next.extended.isNotEmpty) onExtended(next.extended);
        if (next.closed) break;
      }
    } on Object {
      _stopped = true;
    }
    onClosed();
  }
}

class NativeSshSession implements SSHSession {
  NativeSshSession(this._channel) {
    LiveObjects.opened('native ssh channel');
    _pump = _ChannelPump(
      _channel,
      onData: _stdout.add,
      onExtended: _stderr.add,
      onClosed: _finish,
    );
    _stdout
      ..onListen = _pump.start
      ..onPause = _syncPause
      ..onResume = _syncPause;
    _stderr
      ..onListen = _pump.start
      ..onPause = _syncPause
      ..onResume = _syncPause;
    _stdin.stream.listen(
      write,
      onDone: () => unawaited(_channel.eof().catchError((_) {})),
    );
  }

  final rs.SshChannel _channel;
  late final _ChannelPump _pump;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _stdin = StreamController<Uint8List>();
  final _done = Completer<void>();
  int? _exitCode;
  Future<void> _writes = Future.value();

  void _syncPause() {
    final paused =
        (_stdout.hasListener && _stdout.isPaused) ||
        (_stderr.hasListener && _stderr.isPaused);
    if (paused) {
      _pump.pause();
    } else {
      _pump.resume();
    }
  }

  void _finish() {
    if (_done.isCompleted) return;
    LiveObjects.closed('native ssh channel');
    _exitCode = _channel.exitStatus();
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _done.complete();
  }

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  int? get exitCode =>
      _exitCode ?? (_done.isCompleted ? _channel.exitStatus() : null);

  @override
  Future<void> get done => _done.future;

  @override
  void write(Uint8List data) {
    final copy = Uint8List.fromList(data);
    _writes = _writes
        .then((_) => _channel.write(data: copy))
        .catchError((_) {});
  }

  @override
  void resizeTerminal(
    int width,
    int height, [
    int pixelWidth = 0,
    int pixelHeight = 0,
  ]) {
    unawaited(
      _channel.windowChange(columns: width, rows: height).catchError((_) {}),
    );
  }

  @override
  void close() {
    _pump.stop();
    unawaited(_channel.close().catchError((_) {}));
    _finish();
  }

  @override
  Future<int?> waitForExit({Duration? timeout}) async {
    final waiting = done.then((_) => exitCode);
    return timeout == null ? waiting : waiting.timeout(timeout);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}

class NativeForwardChannel implements SSHForwardChannel {
  NativeForwardChannel(this._channel) {
    LiveObjects.opened('native forward channel');
    _pump = _ChannelPump(
      _channel,
      onData: _incoming.add,
      onExtended: (_) {},
      onClosed: _finish,
    );
    _incoming
      ..onListen = _pump.start
      ..onPause = _pump.pause
      ..onResume = _pump.resume
      ..onCancel = () => unawaited(close());
    _outgoing.stream.listen(
      (data) => _writes = _writes
          .then((_) => _channel.write(data: Uint8List.fromList(data)))
          .catchError((_) {}),
      onDone: () =>
          _writes = _writes.then((_) => _channel.eof()).catchError((_) {}),
    );
  }

  final rs.SshChannel _channel;
  late final _ChannelPump _pump;
  final _incoming = StreamController<Uint8List>();
  final _outgoing = StreamController<List<int>>();
  final _done = Completer<void>();
  Future<void> _writes = Future.value();

  void _finish() {
    if (_done.isCompleted) return;
    LiveObjects.closed('native forward channel');
    unawaited(_incoming.close());
    _done.complete();
  }

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    _pump.stop();
    try {
      await _channel.close();
    } on Object {
      return;
    } finally {
      _finish();
    }
  }

  @override
  void destroy() => unawaited(close());

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}

SftpFileAttrs _attrs(rs.SftpAttrs a) => SftpFileAttrs(
  size: a.size?.toInt(),
  userID: a.uid,
  groupID: a.gid,
  mode: a.permissions == null ? null : SftpFileMode.value(a.permissions!),
  accessTime: a.atime,
  modifyTime: a.mtime,
);

class NativeSftpClient implements SftpClient {
  NativeSftpClient(this._sftp) {
    LiveObjects.opened('native sftp session');
  }

  final rs.SftpSession _sftp;
  bool _closed = false;

  @override
  Future<List<SftpName>> listdir(String path) => _guard(
    () async => [
      for (final entry in await _sftp.list(path: path))
        SftpName(
          filename: entry.filename,
          longname: entry.longname,
          attr: _attrs(entry.attrs),
        ),
    ],
  );

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) => _guard(
    () async => _attrs(await _sftp.stat(path: path, followLinks: followLink)),
  );

  @override
  Future<void> setStat(String path, SftpFileAttrs attrs) async {
    final mode = attrs.mode;
    if (mode == null) return;
    await _guard(() => _sftp.setPermissions(path: path, mode: mode.value));
  }

  @override
  Future<void> mkdir(String path, [SftpFileAttrs? attrs]) =>
      _guard(() => _sftp.mkdir(path: path));

  @override
  Future<void> rmdir(String dirname) =>
      _guard(() => _sftp.rmdir(path: dirname));

  @override
  Future<void> remove(String filename) =>
      _guard(() => _sftp.remove(path: filename));

  @override
  Future<void> rename(String oldPath, String newPath) =>
      _guard(() => _sftp.rename(from: oldPath, to: newPath));

  @override
  Future<String> absolute(String path) =>
      _guard(() => _sftp.realpath(path: path));

  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async => NativeSftpFile(
    await _guard(() => _sftp.open(path: path, flags: mode.flag)),
  );

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    LiveObjects.closed('native sftp session');
    try {
      await _sftp.close();
    } on Object {
      return;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}

class NativeSftpFile implements SftpFile {
  NativeSftpFile(this._file) {
    LiveObjects.opened('native sftp file');
  }

  static const chunk = 255 * 1024;
  static const window = 32;

  final rs.SftpFile _file;
  bool _closed = false;

  @override
  Stream<Uint8List> read({
    int chunkSize = chunk,
    int? length,
    int maxPendingRequests = window,
    int offset = 0,
    void Function(int bytes)? onProgress,
  }) async* {
    final end = length == null ? null : offset + length;
    final inflight = <(int, int, Future<Uint8List?>)>[];
    var next = offset;
    var delivered = 0;
    var eof = false;
    Future<Uint8List?> request(int at, int size) =>
        _guard(() => _file.read(offset: BigInt.from(at), len: size));
    void fill() {
      while (!eof &&
          inflight.length < maxPendingRequests &&
          (end == null || next < end)) {
        final size = end == null ? chunkSize : (end - next).clamp(0, chunkSize);
        if (size == 0) break;
        inflight.add((next, size, request(next, size)));
        next += size;
      }
    }

    fill();
    while (inflight.isNotEmpty) {
      final (at, size, pending) = inflight.removeAt(0);
      final data = await pending;
      if (data == null || data.isEmpty) {
        eof = true;
        for (final (_, _, rest) in inflight) {
          unawaited(rest.then((_) {}, onError: (_) {}));
        }
        inflight.clear();
        break;
      }
      delivered += data.length;
      onProgress?.call(delivered);
      yield data;
      if (data.length < size) {
        final rest = at + data.length;
        inflight.insert(0, (
          rest,
          size - data.length,
          request(rest, size - data.length),
        ));
      }
      fill();
    }
  }

  @override
  SftpFileWriter write(
    Stream<Uint8List> stream, {
    int chunkSize = chunk,
    int maxPendingRequests = window,
    int offset = 0,
    void Function(int total)? onProgress,
  }) => NativeSftpWriter(this, stream, offset, onProgress);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    LiveObjects.closed('native sftp file');
    try {
      await _file.close();
    } on Object {
      return;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}

class NativeSftpWriter implements SftpFileWriter {
  NativeSftpWriter(
    this._owner,
    Stream<Uint8List> stream,
    int offset,
    void Function(int total)? onProgress,
  ) {
    unawaited(_run(stream, offset, onProgress));
  }

  static const window = 16;

  final NativeSftpFile _owner;
  final _done = Completer<void>();
  bool _aborted = false;
  StreamSubscription<Uint8List>? _subscription;

  Future<void> _run(
    Stream<Uint8List> stream,
    int offset,
    void Function(int total)? onProgress,
  ) async {
    var position = offset;
    var acknowledged = 0;
    final inflight = <Future<int>>[];
    final buffer = BytesBuilder(copy: false);
    Future<void> send(Uint8List data) async {
      final at = position;
      position += data.length;
      inflight.add(
        _guard(() => _owner._file.write(offset: BigInt.from(at), data: data))
            .then((_) => data.length),
      );
      while (inflight.length >= window) {
        acknowledged += await inflight.removeAt(0);
        onProgress?.call(acknowledged);
      }
    }

    try {
      await for (final data in stream) {
        if (_aborted) break;
        buffer.add(data);
        while (buffer.length >= NativeSftpFile.chunk) {
          final bytes = buffer.takeBytes();
          await send(Uint8List.sublistView(bytes, 0, NativeSftpFile.chunk));
          if (bytes.length > NativeSftpFile.chunk)
            buffer.add(Uint8List.sublistView(bytes, NativeSftpFile.chunk));
        }
      }
      if (!_aborted && buffer.isNotEmpty) await send(buffer.takeBytes());
      for (final pending in inflight) {
        acknowledged += await pending;
        onProgress?.call(acknowledged);
      }
      if (!_done.isCompleted) _done.complete();
    } on Object catch (error, stack) {
      if (!_done.isCompleted) _done.completeError(error, stack);
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> abort() async {
    _aborted = true;
    await _subscription?.cancel();
    if (!_done.isCompleted)
      _done.completeError(SftpAbortError('The transfer was cancelled'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    '${invocation.memberName} is not available in the native SSH engine',
  );
}
