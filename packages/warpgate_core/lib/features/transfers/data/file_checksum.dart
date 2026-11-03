import 'dart:io';

import 'package:cryptography/cryptography.dart';

abstract final class FileChecksum {
  static String? parse(String output) {
    final match = RegExp(r'^([0-9a-fA-F]{64})\b').firstMatch(output.trim());
    return match?.group(1)?.toLowerCase();
  }

  static Future<String?> local(String path) async {
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
