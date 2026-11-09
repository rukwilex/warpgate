import '../frb_generated.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class EngineError implements FrbException {
  final EngineErrorKind kind;
  final String message;
  final int? code;

  const EngineError({required this.kind, required this.message, this.code});

  @override
  int get hashCode => kind.hashCode ^ message.hashCode ^ code.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineError &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          message == other.message &&
          code == other.code;
}

enum EngineErrorKind {
  hostKey,
  auth,
  authAbort,
  keyDecrypt,
  keyDecode,
  timeout,
  socket,
  handshake,
  channel,
  channelRequest,
  cancelled,
  disconnect,
  sftpStatus,
  sftp,
  internal,
}
