import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';

List<(int, int)> dartComments(String source, String path) {
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final ranges = <(int, int)>[];
  Token? token = result.unit.beginToken;
  while (token != null) {
    Token? comment = token.precedingComments;
    while (comment != null) {
      ranges.add((comment.offset, comment.end));
      comment = comment.next;
    }
    if (token.type == TokenType.EOF) break;
    token = token.next;
  }
  return ranges;
}

List<(int, int)> rustComments(String s) {
  final ranges = <(int, int)>[];
  var i = 0;
  final n = s.length;
  bool at(int k, String text) => s.startsWith(text, k);
  while (i < n) {
    final c = s[i];
    if (at(i, '//')) {
      final end = s.indexOf('\n', i);
      ranges.add((i, end < 0 ? n : end));
      i = end < 0 ? n : end;
    } else if (at(i, '/*')) {
      var depth = 0;
      var j = i;
      while (j < n) {
        if (at(j, '/*')) {
          depth++;
          j += 2;
        } else if (at(j, '*/')) {
          depth--;
          j += 2;
          if (depth == 0) break;
        } else {
          j++;
        }
      }
      ranges.add((i, j));
      i = j;
    } else if ((c == 'r' || (c == 'b' && i + 1 < n && s[i + 1] == 'r')) &&
        RegExp('^b?r(#*)"').hasMatch(s.substring(i, (i + 20).clamp(0, n))) &&
        (i == 0 || !RegExp('[A-Za-z0-9_]').hasMatch(s[i - 1]))) {
      final match = RegExp('^b?r(#*)"').firstMatch(s.substring(i))!;
      final close = '"${match.group(1)}';
      final end = s.indexOf(close, i + match.end);
      i = end < 0 ? n : end + close.length;
    } else if (c == '"') {
      var j = i + 1;
      while (j < n && s[j] != '"') {
        j += s[j] == r'\' ? 2 : 1;
      }
      i = j + 1;
    } else if (c == "'") {
      final char = RegExp(r"^'(\\.[^']*|[^\\'\n])'").firstMatch(s.substring(i, (i + 12).clamp(0, n)));
      i += char == null ? 1 : char.end;
    } else {
      i++;
    }
  }
  return ranges;
}

String strip(String source, List<(int, int)> ranges) {
  final out = StringBuffer();
  var at = 0;
  for (final (start, end) in ranges) {
    out.write(source.substring(at, start));
    at = end;
  }
  out.write(source.substring(at));
  return out
      .toString()
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceFirst(RegExp(r'^\n+'), '');
}

Iterable<File> sources(String root) {
  final type = FileSystemEntity.typeSync(root);
  if (type == FileSystemEntityType.notFound) return const [];
  if (type != FileSystemEntityType.directory) return [File(root)];
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.rs'))
      .where((f) => !f.path.contains('/.dart_tool/') && !f.path.contains('/target/') && !f.path.contains('/build/'));
}

void main(List<String> args) {
  final check = args.isNotEmpty && args.first == '--check';
  final roots = check ? args.skip(1) : args;
  var found = 0;
  var files = 0;
  for (final root in roots) {
    for (final file in sources(root)) {
      files++;
      final source = file.readAsStringSync();
      final ranges = file.path.endsWith('.rs') ? rustComments(source) : dartComments(source, file.path);
      if (ranges.isEmpty) continue;
      if (check) {
        for (final (start, end) in ranges) {
          final line = '\n'.allMatches(source.substring(0, start)).length + 1;
          stdout.writeln('${file.path}:$line: ${source.substring(start, end).split('\n').first}');
          found++;
        }
      } else {
        file.writeAsStringSync(strip(source, ranges));
      }
    }
  }
  if (check) {
    stdout.writeln('$files files checked, $found comments');
    exit(found == 0 ? 0 : 1);
  }
}
