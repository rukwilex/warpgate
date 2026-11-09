import '../frb_generated.dart';
import 'error.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

abstract class SshChannel implements RustOpaqueInterface {
  Future<void> close();

  Future<void> eof();

  Future<void> exec({required String command});

  int? exitStatus();

  Future<ChannelChunk> read({required int maxBytes});

  Future<void> requestPty({
    required String term,
    required int columns,
    required int rows,
  });

  Future<void> requestShell();

  Future<void> setEnv({required String name, required String value});

  Future<void> windowChange({required int columns, required int rows});

  Future<void> write({required List<int> data});
}

class ChannelChunk {
  final Uint8List data;
  final Uint8List extended;
  final int? exitStatus;
  final bool closed;

  const ChannelChunk({
    required this.data,
    required this.extended,
    this.exitStatus,
    required this.closed,
  });

  @override
  int get hashCode =>
      data.hashCode ^ extended.hashCode ^ exitStatus.hashCode ^ closed.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelChunk &&
          runtimeType == other.runtimeType &&
          data == other.data &&
          extended == other.extended &&
          exitStatus == other.exitStatus &&
          closed == other.closed;
}
