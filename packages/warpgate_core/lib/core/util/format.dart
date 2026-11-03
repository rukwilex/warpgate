abstract final class Format {
  static const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  static String bytes(int value) {
    if (value < 1024) return '$value B';
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < _units.length - 1) {
      size /= 1024;
      unit++;
    }
    final digits = size >= 100 ? 0 : 1;
    return '${size.toStringAsFixed(digits)} ${_units[unit]}';
  }

  static String speed(double bytesPerSecond) =>
      '${bytes(bytesPerSecond.round())}/s';

  static String duration(Duration value) {
    if (value.inMilliseconds < 1000) return '${value.inMilliseconds} ms';
    if (value.inSeconds < 60) {
      return '${(value.inMilliseconds / 1000).toStringAsFixed(1)} s';
    }
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    if (minutes < 60) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${value.inHours}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  }

  static String eta(int remainingBytes, double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '—';
    final seconds = (remainingBytes / bytesPerSecond).ceil();
    if (seconds < 60) return '$seconds s';
    return duration(Duration(seconds: seconds));
  }

  static String mode(int mode) {
    const symbols = 'rwxrwxrwx';
    final buffer = StringBuffer();
    for (var i = 0; i < 9; i++) {
      buffer.write(mode & (1 << (8 - i)) != 0 ? symbols[i] : '-');
    }
    return buffer.toString();
  }

  static String octal(int mode) =>
      (mode & 0x1FF).toRadixString(8).padLeft(3, '0');

  static String time(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String clock(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  static String plural(int count, String one, [String? many]) =>
      '$count ${count == 1 ? one : (many ?? '${one}s')}';
}
