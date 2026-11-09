class TypeAheadBuffer {
  String _typed = '';
  DateTime _typedAt = DateTime(0);

  String add(
    String character, {
    required DateTime now,
    required Duration window,
  }) {
    final fresh = now.difference(_typedAt) > window;
    _typed = (fresh ? '' : _typed) + character.toLowerCase();
    _typedAt = now;
    return _typed;
  }
}
