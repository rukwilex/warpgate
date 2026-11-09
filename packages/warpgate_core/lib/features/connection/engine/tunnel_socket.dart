import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/dart/dart_ssh_client.dart';

SSHForwardChannel tunnelSocket(SshTunnel tunnel) =>
    tunnel is DartSshTunnel ? tunnel.channel : TunnelSocket(tunnel);

class TunnelSocket implements SSHForwardChannel {
  new(this._tunnel);

  final SshTunnel _tunnel;

  @override
  Stream<Uint8List> get stream => _tunnel.stream;

  @override
  StreamSink<List<int>> get sink => _tunnel.sink;

  @override
  Future<void> get done => _tunnel.done;

  @override
  Future<void> close() => _tunnel.close();

  @override
  void destroy() => unawaited(_tunnel.close());

  @override
  Future<void> flush() async {}
}
