abstract final class LiveObjects {
  static final Map<String, int> _counts = {};
  static final Map<String, int> _created = {};

  static void opened(String kind) {
    _counts[kind] = (_counts[kind] ?? 0) + 1;
    _created[kind] = (_created[kind] ?? 0) + 1;
  }

  static void closed(String kind) {
    final next = (_counts[kind] ?? 0) - 1;
    if (next <= 0) {
      _counts.remove(kind);
    } else {
      _counts[kind] = next;
    }
  }

  static int count(String kind) => _counts[kind] ?? 0;

  static int created(String kind) => _created[kind] ?? 0;

  static Map<String, int> snapshot() => Map.unmodifiable(_counts);

}
