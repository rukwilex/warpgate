import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final file = File(args.isEmpty ? '../../../build/perf/results.jsonl' : args.first);
  final skip = {'scenario', 'label', 'at'};
  final groups = <String, List<Map<String, Object?>>>{};
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final row = (jsonDecode(line) as Map).cast<String, Object?>();
    final label = '${row['label']}';
    if (label == 'smoke' || label == 'run' || label.contains('dbg')) continue;
    final key = [
      row['scenario'],
      if (row['load'] != null) row['load'],
      if (row['columns'] != null) '${row['columns']} cols ${row['lines']} lines',
      if (row['panes'] != null) '${row['panes']} panes',
      if (row['sort'] != null) row['sort'],
    ].join(' / ');
    (groups[key] ??= []).add(row);
  }
  for (final MapEntry(key: name, value: rows) in groups.entries) {
    final latest = <String, Map<String, Object?>>{};
    for (final row in rows) {
      latest['${row['label']}'] = row;
    }
    final columns = <String>[];
    for (final row in latest.values) {
      for (final key in row.keys) {
        if (skip.contains(key) || columns.contains(key)) continue;
        final value = row[key];
        if (value is Map || value is List) continue;
        columns.add(key);
      }
    }
    stdout
      ..writeln('### $name')
      ..writeln()
      ..writeln('| label | ${columns.join(' | ')} |')
      ..writeln('|---|${columns.map((_) => '---').join('|')}|');
    for (final MapEntry(key: label, value: row) in latest.entries) {
      stdout.writeln('| $label | ${columns.map((c) => row[c] ?? '').join(' | ')} |');
    }
    stdout.writeln();
  }
}
