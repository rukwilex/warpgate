import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/dart/dart_sftp.dart';

class DartSshClient implements SshClient {
  DartSshClient(this._client);

  final SSHClient _client;
  final Map<SshRemoteForward, SSHRemoteForward> _remotes = {};

  @override
  String get username => _client.username;

  @override
  String? get remoteVersion => _client.remoteVersion;

  @override
  Future<void> get done => _client.done;

  @override
  bool get isClosed => _client.isClosed;

  @override
  Future<void> ping() => _client.ping();

  @override
  Future<void> close() async => _client.close();

  @override
  Future<SshSession> shell({
    SSHPtyConfig? pty = const SSHPtyConfig(),
    Map<String, String>? environment,
  }) async => DartSshSession(await _client.shell(pty: pty, environment: environment));

  @override
  Future<SshSession> execute(
    String command, {
    SSHPtyConfig? pty,
    Map<String, String>? environment,
  }) async => DartSshSession(await _client.execute(command, pty: pty, environment: environment));

  @override
  Future<SshSftp> sftp() async => DartSftp(await _client.sftp());

  @override
  Future<SshTunnel> forwardLocal(String host, int port) async =>
      DartSshTunnel(await _client.forwardLocal(host, port));

  @override
  Future<SshRemoteForward?> forwardRemote({
    String? host,
    int? port,
    RemoteConnectionFilter? filter,
  }) async {
    final remote = await _client.forwardRemote(host: host, port: port, filter: filter);
    if (remote == null) return null;
    final wrapped = DartRemoteForward(remote);
    _remotes[wrapped] = remote;
    return wrapped;
  }

  @override
  Future<bool> cancelForwardRemote(SshRemoteForward forward) async {
    final remote = _remotes.remove(forward);
    if (remote == null) return false;
    return _client.cancelForwardRemote(remote);
  }

  @override
  Future<SSHDynamicForward> forwardDynamic({String bindHost = '127.0.0.1', int? bindPort}) =>
      _client.forwardDynamic(bindHost: bindHost, bindPort: bindPort);
}

class DartSshSession implements SshSession {
  DartSshSession(this._session);

  final SSHSession _session;

  @override
  StreamSink<Uint8List> get stdin => _session.stdin;

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  int? get exitCode => _session.exitCode;

  @override
  Future<void> get done => _session.done;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resizeTerminal(int columns, int rows) => _session.resizeTerminal(columns, rows);

  @override
  void close() => _session.close();

  @override
  Future<int?> waitForExit({Duration? timeout}) => _session.waitForExit(timeout: timeout);
}

class DartSshTunnel implements SshTunnel {
  DartSshTunnel(this.channel);

  final SSHForwardChannel channel;

  @override
  Stream<Uint8List> get stream => channel.stream;

  @override
  StreamSink<List<int>> get sink => channel.sink;

  @override
  Future<void> get done => channel.done;

  @override
  Future<void> close() => channel.close();
}

class DartRemoteForward implements SshRemoteForward {
  DartRemoteForward(this._remote);

  final SSHRemoteForward _remote;

  @override
  String get host => _remote.host;

  @override
  int get port => _remote.port;

  @override
  Stream<SshTunnel> get connections => _remote.connections.map(DartSshTunnel.new);
}
