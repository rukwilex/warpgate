abstract final class DiagnosticFormat {
  static String megabytes(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number < 10 ? number.toStringAsFixed(1) : number.toStringAsFixed(0);
  }

  static String milliseconds(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number < 10 ? number.toStringAsFixed(1) : number.toStringAsFixed(0);
  }

  static String clockTime(String iso) {
    final at = DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}
