import 'package:flutter/foundation.dart';

@immutable
class SshConfigEntry {
  const new({
    required this.alias,
    required this.hostName,
    required this.user,
    required this.port,
    this.identityFile,
    this.proxyJump,
  });

  final String alias;
  final String hostName;
  final String? user;
  final int port;
  final String? identityFile;
  final String? proxyJump;
}

abstract final class SshConfigParser {
  static List<SshConfigEntry> parse(String source) {
    final blocks = <({List<String> patterns, Map<String, String> options})>[];
    final globals = <String, String>{};
    Map<String, String>? current = globals;
    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final match = RegExp(r'^(\S+)\s*[=\s]\s*(.+)$').firstMatch(line);
      if (match == null) continue;
      final key = match.group(1)!.toLowerCase();
      final value = _unquote(match.group(2)!.trim());
      if (key == 'host') {
        current = {};
        blocks.add((patterns: value.split(RegExp(r'\s+')), options: current));
        continue;
      }
      if (key == 'match') {
        current = null;
        continue;
      }
      current?.putIfAbsent(key, () => value);
    }
    final aliases = <String>[
      for (final block in blocks)
        for (final pattern in block.patterns)
          if (!_isPattern(pattern)) pattern,
    ];
    return [
      for (final alias in aliases.toSet())
        _entry(alias, _resolve(alias, globals, blocks)),
    ];
  }

  static Map<String, String> _resolve(
    String alias,
    Map<String, String> globals,
    List<({List<String> patterns, Map<String, String> options})> blocks,
  ) {
    final options = {...globals};
    for (final block in blocks) {
      final negated = block.patterns.any(
        (p) => p.startsWith('!') && _glob(p.substring(1), alias),
      );
      if (negated ||
          !block.patterns.any((p) => !p.startsWith('!') && _glob(p, alias))) {
        continue;
      }
      for (final MapEntry(:key, :value) in block.options.entries) {
        options.putIfAbsent(key, () => value);
      }
    }
    return options;
  }

  static bool _glob(String pattern, String value) {
    final regex = RegExp(
      '^${RegExp.escape(pattern).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$',
    );
    return regex.hasMatch(value);
  }

  static SshConfigEntry _entry(String alias, Map<String, String> options) =>
      SshConfigEntry(
        alias: alias,
        hostName: options['hostname'] ?? alias,
        user: options['user'],
        port: int.tryParse(options['port'] ?? '') ?? 22,
        identityFile: options['identityfile'],
        proxyJump: options['proxyjump'],
      );

  static bool _isPattern(String alias) =>
      alias.contains('*') || alias.contains('?') || alias.startsWith('!');

  static String _unquote(String value) =>
      value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;
}
