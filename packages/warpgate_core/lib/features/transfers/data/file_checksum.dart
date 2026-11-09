import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:warpgate_core/core/util/worker.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';

abstract final class FileChecksum {
  static String? parse(String output) {
    final match = RegExp(r'^([0-9a-fA-F]{64})\b').firstMatch(output.trim());
    return match?.group(1)?.toLowerCase();
  }

  static Future<String?> local(String path) async {
    if (!File(path).existsSync()) return null;
    if (NativeEngine.available) {
      try {
        return await NativeEngine.sha256File(path);
      } on Object {
        return await Worker.named('io').run(() => _local(path));
      }
    }
    return await Worker.named('io').run(() => _local(path));
  }

  static Future<String?> _local(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final sink = Sha256().newHashSink();
    await file.openRead().forEach(sink.add);
    sink.close();
    final hash = await sink.hash();
    return [
      for (final byte in hash.bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
