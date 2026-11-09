import 'dart:convert';
import 'dart:io';

import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/util/format.dart';

class Output {
  new({
    required this.json,
    required this.quiet,
    required bool noColor,
    required this.verbose,
    StringSink? out,
    StringSink? err,
    bool? color,
    bool? stdoutTty,
    bool? stderrTty,
    Map<String, String>? environment,
  }) : _out = out ?? stdout,
       _err = err ?? stderr,
       stdoutIsTty = stdoutTty ?? stdout.hasTerminal,
       stderrIsTty = stderrTty ?? stderr.hasTerminal,
       color =
           color ??
           (!noColor &&
               !(environment ?? Platform.environment).containsKey('NO_COLOR') &&
               (environment ?? Platform.environment)['TERM'] != 'dumb' &&
               stdout.hasTerminal &&
               stdout.supportsAnsiEscapes);

  final bool json;
  final bool quiet;
  final bool verbose;
  final bool color;
  final bool stdoutIsTty;
  final bool stderrIsTty;
  final StringSink _out;
  final StringSink _err;

  bool get showProgress =>
      !json && !quiet && stdoutIsTty && stderrIsTty;

  String _ansi(String code, String text) =>
      color ? '\x1B[${code}m$text\x1B[0m' : text;

  String dim(String text) => _ansi('2', text);

  String red(String text) => _ansi('31', text);

  String green(String text) => _ansi('32', text);

  String yellow(String text) => _ansi('33', text);

  void line(String text) => _out.writeln(text);

  void write(String text) => _out.write(text);

  void note(String text) {
    if (!quiet && !json) _err.writeln(text);
  }

  void debug(String text) {
    if (verbose) _err.writeln(dim(text));
  }

  void raw(String text) => _err.write(text);

  void emit(ActionSpec action, JsonMap result) {
    _out.writeln(encode(action.schemaId, result));
  }

  static String encode(String schema, JsonMap result) =>
      const JsonEncoder.withIndent('  ').convert({'schema': schema, ...result});

  void failure(ActionFailure failure) {
    if (json) {
      _err.writeln(
        jsonEncode({
          'schema': 'warpgate.error/1',
          'code': failure.kind.code,
          'kind': failure.kind.name,
          'message': failure.message,
          'hint': failure.hint,
        }),
      );
      return;
    }
    _err.writeln('${red('error:')} ${failure.message}');
    if (failure.hint != null) _err.writeln(failure.hint);
  }

  String dot(String status) {
    final text = _ansi(
      switch (status) {
        'connected' => '32',
        'busy' => '33',
        'connecting' => '33',
        'dropped' => '31',
        _ => '2',
      },
      '●',
    );
    return text;
  }

  static String cell(Object? value, ColumnFormat format) {
    if (value == null) return '-';
    switch (format) {
      case ColumnFormat.bytes:
        return value is int ? Format.bytes(value) : '$value';
      case ColumnFormat.id:
        final text = '$value';
        return text.length > 8 ? text.substring(0, 8) : text;
      case ColumnFormat.time:
        final parsed = DateTime.tryParse('$value');
        if (parsed == null) return '$value';
        final local = parsed.toLocal();
        String two(int part) => part.toString().padLeft(2, '0');
        return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
      case ColumnFormat.text || ColumnFormat.number || ColumnFormat.status:
        if (value is List) return value.isEmpty ? '-' : value.join(', ');
        if (value is bool) return value ? 'yes' : 'no';
        return '$value';
    }
  }

  static int visibleLength(String value) =>
      value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').runes.length;

  String table(TableSpec spec, List<JsonMap> rows) {
    final columns = spec.columns
        .where((column) => column.format != ColumnFormat.status || color)
        .toList();
    final cells = [
      for (final row in rows)
        [
          for (final column in columns)
            if (column.format == ColumnFormat.status)
              dot('${row[column.key]}')
            else
              cell(row[column.key], column.format),
        ],
    ];
    final widths = [
      for (final (index, column) in columns.indexed)
        [
          column.label.length,
          for (final row in cells) visibleLength(row[index]),
        ].reduce((a, b) => a > b ? a : b),
    ];
    bool right(TableColumn column) =>
        column.format == ColumnFormat.number || column.format == ColumnFormat.bytes;
    String align(String value, int index) {
      final padding = ' ' * (widths[index] - visibleLength(value));
      return right(columns[index]) ? '$padding$value' : '$value$padding';
    }

    final out = StringBuffer();
    if (!quiet) {
      out.writeln(
        dim(
          [
            for (final (index, column) in columns.indexed)
              align(column.label, index),
          ].join('  ').trimRight(),
        ),
      );
    }
    for (final row in cells) {
      out.writeln(
        [
          for (final (index, value) in row.indexed) align(value, index),
        ].join('  ').trimRight(),
      );
    }
    return out.toString().trimRight();
  }

  static String fill(String template, JsonMap values) =>
      template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
        final key = match.group(1)!;
        return values.containsKey(key) ? '${values[key] ?? ''}' : match.group(0)!;
      });

  static List<String> flatten(JsonMap values, [String prefix = '']) {
    final lines = <String>[];
    for (final MapEntry(:key, :value) in values.entries) {
      final name = '$prefix$key';
      if (value is Map) {
        lines.addAll(flatten(value.cast(), '$name.'));
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        for (final (index, item) in value.indexed) {
          lines.addAll(flatten((item as Map).cast(), '$name[$index].'));
        }
      } else {
        lines.add('$name: ${cell(value, ColumnFormat.text)}');
      }
    }
    return lines;
  }

  void render(ActionSpec action, JsonMap result) {
    if (json) {
      emit(action, result);
      return;
    }
    final table = action.table;
    if (table != null) {
      final rows = ((result[table.rows] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map((row) => row.cast<String, Object?>())
          .toList();
      if (rows.isEmpty) {
        note('Nothing to show');
      } else {
        line(this.table(table, rows));
      }
      return;
    }
    final text = action.text;
    if (text != null) {
      if (!quiet || text.startsWith('{')) line(fill(text, result));
      return;
    }
    flatten(result).forEach(line);
  }
}
