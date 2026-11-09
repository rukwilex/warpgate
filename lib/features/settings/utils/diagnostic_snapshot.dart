typedef Snapshot = Map<String, Object?>;

abstract final class DiagnosticSnapshot {
  static Map<String, Object?> map(Object? value) =>
      (value as Map?)?.cast<String, Object?>() ?? const {};

  static List<Map<String, Object?>> list(Object? value) =>
      ((value as List?) ?? const []).map(map).toList();
}
