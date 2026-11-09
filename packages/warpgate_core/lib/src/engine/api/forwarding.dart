import '../frb_generated.dart';
import 'channel.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

abstract class ForwardedConnection implements RustOpaqueInterface {
  SshChannel get channel;

  String get connectedHost;

  int get connectedPort;

  String get originHost;

  int get originPort;

  set channel(SshChannel channel);

  set connectedHost(String connectedHost);

  set connectedPort(int connectedPort);

  set originHost(String originHost);

  set originPort(int originPort);
}
