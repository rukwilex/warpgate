import 'dart:collection';
import 'dart:ui';

import 'package:flutter/widgets.dart';

class ParagraphCache {
  ParagraphCache._();

  static final instance = ParagraphCache._();

  static int maximumSize = 4096;

  final _cache = LinkedHashMap<int, Paragraph>();
  final _fonts = <Object, int>{};

  int hits = 0;
  int misses = 0;
  int evictions = 0;

  int fontId(TerminalStyleKey key) {
    final existing = _fonts[key];
    if (existing != null) return existing;
    if (_fonts.length >= 255) {
      _fonts.clear();
      clear();
    }
    final id = _fonts.length + 1;
    _fonts[key] = id;
    return id;
  }

  static int keyOf(int font, int codePoint, int style, int color) =>
      (font << 56) | (style << 53) | (codePoint << 32) | (color & 0xffffffff);

  Paragraph? getLayoutFromCache(int key) {
    final paragraph = _cache.remove(key);
    if (paragraph == null) {
      misses++;
      return null;
    }
    hits++;
    _cache[key] = paragraph;
    return paragraph;
  }

  Paragraph performAndCacheLayout(
    String text,
    TextStyle style,
    TextScaler textScaler,
    int key,
  ) {
    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(style.getTextStyle(textScaler: textScaler));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    _cache[key] = paragraph;
    while (_cache.length > maximumSize) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)!.dispose();
      evictions++;
    }
    return paragraph;
  }

  void trim(int keep) {
    while (_cache.length > keep) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)!.dispose();
      evictions++;
    }
  }

  void clear() => trim(0);

  int get length => _cache.length;
}

@immutable
class TerminalStyleKey {
  const TerminalStyleKey(this.style, this.scaler);

  final Object style;
  final TextScaler scaler;

  @override
  bool operator ==(Object other) =>
      other is TerminalStyleKey &&
      other.style == style &&
      other.scaler == scaler;

  @override
  int get hashCode => Object.hash(style, scaler);
}
