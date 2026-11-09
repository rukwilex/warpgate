abstract final class ExportFileNames {
  static String backup(DateTime now) =>
      'warpgate-${now.toIso8601String().substring(0, 10)}.wgbackup';

  static String diagnostics(DateTime now) {
    final stamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return 'warpgate-diagnostics-$stamp.json';
  }
}
