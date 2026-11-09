import 'dart:async';
import 'dart:typed_data';

import 'package:warpgate_core/features/connection/data/ssh_connector.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart' show CancelToken;

class FakeSshClient implements SshClient {
  new(this.hostId, {this.jump});

  final String hostId;
  final SshClient? jump;
  final _done = Completer<void>();
  bool closed = false;
  int pings = 0;
  int sftpOpens = 0;
  Completer<void>? hangingPing;

  void drop(Object error) {
    if (!_done.isCompleted) _done.completeError(error);
  }

  @override
  String get username => 'tester';

  @override
  String? get remoteVersion => 'SSH-2.0-Fake';

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => closed || _done.isCompleted;

  @override
  Future<void> ping() {
    pings++;
    return hangingPing?.future ?? Future.value();
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<SshSession> shell({SSHPtyConfig? pty, Map<String, String>? environment}) async => FakeSession(null);

  @override
  Future<SshSession> execute(String command, {SSHPtyConfig? pty, Map<String, String>? environment}) async =>
      FakeSession(command);

  @override
  Future<SshSftp> sftp() async {
    sftpOpens++;
    return FakeSftp();
  }

  @override
  Future<SshTunnel> forwardLocal(String host, int port) => throw UnimplementedError();

  @override
  Future<SshRemoteForward?> forwardRemote({String? host, int? port, RemoteConnectionFilter? filter}) async => null;

  @override
  Future<bool> cancelForwardRemote(SshRemoteForward forward) async => false;

  @override
  Future<SSHDynamicForward> forwardDynamic({String bindHost = '127.0.0.1', int? bindPort}) =>
      throw UnimplementedError();
}

class FakeSession implements SshSession {
  new(this.command) {
    final text = command;
    if (text != null) {
      _stdout.add(Uint8List.fromList(text.codeUnits));
    }
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  final String? command;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _stdin = StreamController<Uint8List>();

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  int? get exitCode => 0;

  @override
  Future<void> get done => Future.value();

  @override
  void write(Uint8List data) {}

  @override
  void resizeTerminal(int columns, int rows) {}

  @override
  void close() {}

  @override
  Future<int?> waitForExit({Duration? timeout}) async => 0;
}

class FakeSftp implements SshSftp {
  @override
  Future<List<SftpName>> listdir(String path) async => const [];

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async => SftpFileAttrs();

  @override
  Future<void> setStat(String path, SftpFileAttrs attrs) async {}

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<void> rmdir(String path) async {}

  @override
  Future<void> remove(String path) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<String> absolute(String path) async => '/home/tester';

  @override
  Future<SshSftpFile> open(String path, {SftpFileOpenMode mode = SftpFileOpenMode.read}) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {}
}

class ConnectCall {
  new(this.host, this.jump, this.cancel);

  final Host host;
  final SshClient? jump;
  final CancelToken cancel;
  final result = Completer<SshClient>();
  FakeSshClient? client;

  FakeSshClient succeed() {
    final made = FakeSshClient(host.id, jump: jump);
    client = made;
    result.complete(made);
    return made;
  }

  void fail(Object error) => result.completeError(error);
}

class FakeConnector implements SshConnector {
  new({this.manual = false, this.honourCancel = true});

  final bool manual;
  final bool honourCancel;
  final calls = <ConnectCall>[];

  Iterable<ConnectCall> callsFor(String hostId) => calls.where((call) => call.host.id == hostId);

  FakeSshClient? clientFor(String hostId) => callsFor(hostId).lastOrNull?.client;

  @override
  Future<SshClient> open(Host host, {required CancelToken cancel, SshClient? jump}) {
    final call = ConnectCall(host, jump, cancel);
    calls.add(call);
    if (honourCancel) {
      cancel.onCancel(() {
        if (!call.result.isCompleted) call.fail(const ConnectCancelledException());
      });
    }
    if (!manual) call.succeed();
    return call.result.future;
  }
}
