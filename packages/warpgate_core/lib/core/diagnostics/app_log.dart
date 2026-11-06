import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

enum LogLevel { info, warning, error }

class LogEntry {
  const new(this.at, this.level, this.area, this.message);

  final DateTime at;
  final LogLevel level;
  final String area;
  final String message;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'level': level.name,
    'area': area,
    'message': message,
  };

  String get line => '${at.toIso8601String()} ${level.name.toUpperCase().padRight(7)} [$area] $message';
}

class AppLog {
  new({
    this.directory,
    this.maxFileBytes = 1 << 20,
    this.maxFiles = 5,
    this.maxAge = const Duration(days: 14),
    this.keepInMemory = 500,
  });

  static AppLog instance = AppLog();

  final String? directory;
  final int maxFileBytes;
  final int maxFiles;
  final Duration maxAge;
  final int keepInMemory;

  final ListQueue<LogEntry> _recent = ListQueue();
  final List<String> _pending = [];
  Future<void>? _flushing;
  int _written = -1;
  int dropped = 0;

  List<LogEntry> get recent => List.unmodifiable(_recent);

  String? get currentFile => directory == null ? null : p.join(directory!, 'warpgate.log');

  void info(String area, String message) => add(LogLevel.info, area, message);

  void warning(String area, String message) => add(LogLevel.warning, area, message);

  void error(String area, Object error, [StackTrace? stack]) {
    final text = stack == null ? '$error' : '$error\n${_trim(stack)}';
    add(LogLevel.error, area, text);
  }

  static String _trim(StackTrace stack) {
    final lines = LineSplitter.split('$stack').take(25);
    return lines.join('\n');
  }

  void add(LogLevel level, String area, String message) {
    final entry = LogEntry(DateTime.now(), level, area, message.length > 4000 ? '${message.substring(0, 4000)}…' : message);
    _recent.add(entry);
    while (_recent.length > keepInMemory) {
      _recent.removeFirst();
    }
    if (directory == null) return;
    if (_pending.length > 2000) {
      dropped++;
      return;
    }
    _pending.add(entry.line);
    _flushing ??= Future<void>.delayed(const Duration(milliseconds: 200), _flush);
  }

  Future<void> flush() async {
    await _flushing;
    if (_pending.isNotEmpty) await _flush();
  }

  Future<void> _flush() async {
    try {
      final path = currentFile!;
      final file = File(path);
      if (_written < 0) {
        await Directory(directory!).create(recursive: true);
        _written = await file.exists() ? await file.length() : 0;
        await prune();
      }
      final text = '${_pending.join('\n')}\n';
      _pending.clear();
      await file.writeAsString(text, mode: FileMode.append, flush: false);
      _written += text.length;
      if (_written > maxFileBytes) await _rotate();
    } on Object {
      _pending.clear();
    } finally {
      _flushing = null;
    }
  }

  Future<void> _rotate() async {
    final base = currentFile!;
    for (var i = maxFiles - 1; i >= 1; i--) {
      final from = File(i == 1 ? base : '$base.${i - 1}');
      if (await from.exists()) await from.rename('$base.$i');
    }
    _written = 0;
    await prune();
  }

  Future<void> prune() async {
    final dir = directory;
    if (dir == null) return;
    final now = DateTime.now();
    await for (final entity in Directory(dir).list()) {
      if (entity is! File || !p.basename(entity.path).startsWith('warpgate.log')) continue;
      final suffix = p.basename(entity.path).substring('warpgate.log'.length);
      final index = suffix.isEmpty ? 0 : int.tryParse(suffix.substring(1)) ?? maxFiles;
      final old = now.difference(await entity.lastModified()) > maxAge;
      if (index >= maxFiles || (index > 0 && old)) await entity.delete();
    }
  }

  Future<int> diskBytes() async {
    final dir = directory;
    if (dir == null || !await Directory(dir).exists()) return 0;
    var total = 0;
    await for (final entity in Directory(dir).list()) {
      if (entity is File && p.basename(entity.path).startsWith('warpgate.log')) total += await entity.length();
    }
    return total;
  }
}
