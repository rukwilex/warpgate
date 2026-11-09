import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_core/core/errors/exit_codes.dart';

abstract final class Editors {
  static String command() {
    final environment = Platform.environment;
    return environment['VISUAL'] ?? environment['EDITOR'] ?? (Platform.isWindows ? 'notepad' : 'vi');
  }

  static Future<String> editText(String initial) async {
    final editor = command();
    final temp = await Directory.systemTemp.createTemp('warpgate-snippet-');
    final file = File(p.join(temp.path, 'snippet.sh'));
    await file.writeAsString(initial);
    try {
      final words = editor.split(' ');
      final process = await Process.start(
        words.first,
        [...words.skip(1), file.path],
        mode: ProcessStartMode.inheritStdio,
      );
      if (await process.exitCode != 0) {
        throw ActionFailure('$editor did not finish cleanly. Nothing was saved');
      }
      return (await file.readAsString()).trimRight();
    } finally {
      await temp.delete(recursive: true);
    }
  }
}
