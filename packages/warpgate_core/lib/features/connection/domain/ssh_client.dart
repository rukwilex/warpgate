import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart'
    show SSHDynamicForward, SSHPtyConfig, SftpFileAttrs, SftpFileOpenMode, SftpName;

export 'package:dartssh2/dartssh2.dart'
    show SSHDynamicForward, SSHPtyConfig, SftpFileAttrs, SftpFileMode, SftpFileOpenMode, SftpName;

typedef RemoteConnectionFilter = bool Function(String host, int port);

abstract interface class SshClient {
  String get username;

  String? get remoteVersion;

  Future<void> get done;

  bool get isClosed;

  Future<void> ping();

  Future<void> close();

  Future<SshSession> shell({SSHPtyConfig? pty, Map<String, String>? environment});

  Future<SshSession> execute(String command, {SSHPtyConfig? pty, Map<String, String>? environment});

  Future<SshSftp> sftp();

  Future<SshTunnel> forwardLocal(String host, int port);

  Future<SshRemoteForward?> forwardRemote({String? host, int? port, RemoteConnectionFilter? filter});

  Future<bool> cancelForwardRemote(SshRemoteForward forward);

  Future<SSHDynamicForward> forwardDynamic({String bindHost, int? bindPort});
}

abstract interface class SshSession {
  StreamSink<Uint8List> get stdin;

  Stream<Uint8List> get stdout;

  Stream<Uint8List> get stderr;

  int? get exitCode;

  Future<void> get done;

  void write(Uint8List data);

  void resizeTerminal(int columns, int rows);

  void close();

  Future<int?> waitForExit({Duration? timeout});
}

abstract interface class SshTunnel {
  Stream<Uint8List> get stream;

  StreamSink<List<int>> get sink;

  Future<void> get done;

  Future<void> close();
}

abstract interface class SshRemoteForward {
  String get host;

  int get port;

  Stream<SshTunnel> get connections;
}

abstract interface class SshSftp {
  Future<List<SftpName>> listdir(String path);

  Future<SftpFileAttrs> stat(String path, {bool followLink = true});

  Future<void> setStat(String path, SftpFileAttrs attrs);

  Future<void> mkdir(String path);

  Future<void> rmdir(String path);

  Future<void> remove(String path);

  Future<void> rename(String from, String to);

  Future<String> absolute(String path);

  Future<SshSftpFile> open(String path, {SftpFileOpenMode mode = SftpFileOpenMode.read});

  Future<void> close();
}

abstract interface class SshSftpFile {
  Stream<Uint8List> read({int? length, int offset = 0, void Function(int bytes)? onProgress});

  SshSftpWriter write(Stream<Uint8List> data, {int offset = 0, void Function(int total)? onProgress});

  Future<void> close();
}

abstract interface class SshSftpWriter {
  Future<void> get done;

  Future<void> abort();
}
