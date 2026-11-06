import 'dart:math';

abstract final class Load {
  static const _words = [
    'Compiling', 'warpgate_core', 'v1.0.0', 'Running', 'build_runner', 'src/main.rs',
    'target/release', 'Finished', 'warning:', 'unused', 'variable', 'index.ts',
    'node_modules/.bin/tsc', '--project', 'tsconfig.json', 'PASS', 'FAIL', 'ok',
    'test', 'result:', 'lib/features/terminal/data/terminal_session.dart', '12ms',
  ];

  static String buildLog(int lines, {int seed = 7}) {
    final random = Random(seed);
    final out = StringBuffer();
    for (var i = 0; i < lines; i++) {
      final level = random.nextInt(10);
      if (level == 0) out.write('\x1b[33m');
      if (level == 1) out.write('\x1b[1;31m');
      if (level == 2) out.write('\x1b[32m');
      out.write('[${(i * 37 % 86400).toString().padLeft(5, '0')}] ');
      final count = 4 + random.nextInt(10);
      for (var w = 0; w < count; w++) {
        out
          ..write(_words[random.nextInt(_words.length)])
          ..write(' ');
      }
      if (level < 3) out.write('\x1b[0m');
      out.write('\r\n');
    }
    return out.toString();
  }

  static String yes(int bytes) => 'y\r\n' * (bytes ~/ 3);

  static String paths(int lines, {int seed = 3}) {
    final random = Random(seed);
    final out = StringBuffer();
    for (var i = 0; i < lines; i++) {
      out.write('/usr');
      final depth = 2 + random.nextInt(6);
      for (var d = 0; d < depth; d++) {
        out
          ..write('/')
          ..write(_words[random.nextInt(_words.length)].replaceAll('/', '_'));
      }
      out.write('\r\n');
    }
    return out.toString();
  }

  static String fullScreen(int frames, {int columns = 120, int rows = 40, int seed = 5}) {
    final random = Random(seed);
    final out = StringBuffer();
    for (var f = 0; f < frames; f++) {
      out.write('\x1b[H');
      for (var r = 0; r < rows; r++) {
        out.write('\x1b[${r + 1};1H');
        for (var c = 0; c < columns; c += 8) {
          out
            ..write('\x1b[38;5;${random.nextInt(256)}m')
            ..write('${(random.nextDouble() * 100).toStringAsFixed(1).padLeft(6)}  ');
        }
      }
      out.write('\x1b[0m');
    }
    return out.toString();
  }

  static String trueColor(int lines, {int columns = 120}) {
    final out = StringBuffer();
    for (var i = 0; i < lines; i++) {
      for (var c = 0; c < columns; c++) {
        final r = (i * 7 + c * 3) % 256;
        final g = (i * 3 + c * 5) % 256;
        final b = (i + c * 11) % 256;
        out.write('\x1b[38;2;$r;$g;${b}m${String.fromCharCode(0x21 + (c + i) % 90)}');
      }
      out.write('\x1b[0m\r\n');
    }
    return out.toString();
  }
}
