import 'dart:convert';

import 'package:test/test.dart';
import 'package:warpgate_cli/warpgate_cli.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

Output make({bool json = false, bool color = false, bool quiet = false, StringBuffer? out, StringBuffer? err}) => Output(
  json: json,
  quiet: quiet,
  noColor: !color,
  verbose: false,
  out: out ?? StringBuffer(),
  err: err ?? StringBuffer(),
  color: color,
  stdoutTty: false,
  stderrTty: false,
);

void main() {
  const spec = TableSpec('rows', [
    TableColumn('status', '', format: ColumnFormat.status),
    TableColumn('name', 'NAME'),
    TableColumn('port', 'PORT', format: ColumnFormat.number),
    TableColumn('size', 'SIZE', format: ColumnFormat.bytes),
  ]);
  final rows = [
    {'status': 'connected', 'name': 'a', 'port': 22, 'size': 2048},
    {'status': 'idle', 'name': 'longer', 'port': 2222, 'size': 5},
  ];

  test('tables align and right-align numbers', () {
    expect(make().table(spec, rows), 'NAME    PORT    SIZE\na         22  2.0 KB\nlonger  2222     5 B');
  });
  test('the status dot only shows with color', () {
    expect(make().table(spec, rows), isNot(contains('●')));
    final colored = make(color: true).table(spec, rows);
    expect(colored, contains('●'));
    expect(colored, contains('\x1B[32m'));
  });
  test('no ANSI escapes without color', () {
    expect(make().table(spec, rows), isNot(contains('\x1B')));
  });
  test('--quiet drops the header', () {
    expect(make(quiet: true).table(spec, rows), isNot(contains('NAME')));
  });
  test('NO_COLOR turns color off', () {
    final output = Output(json: false, quiet: false, noColor: false, verbose: false, stdoutTty: true, stderrTty: true, environment: {'NO_COLOR': '1'});
    expect(output.color, isFalse);
  });
  test('progress stays off unless both streams are terminals', () {
    expect(make().showProgress, isFalse);
    expect(Output(json: true, quiet: false, noColor: true, verbose: false, stdoutTty: true, stderrTty: true).showProgress, isFalse);
    expect(Output(json: false, quiet: false, noColor: true, verbose: false, stdoutTty: true, stderrTty: true).showProgress, isTrue);
  });
  test('cells', () {
    expect(Output.cell(null, ColumnFormat.text), '-');
    expect(Output.cell(['a', 'b'], ColumnFormat.text), 'a, b');
    expect(Output.cell(true, ColumnFormat.text), 'yes');
    expect(Output.cell('0d2fb383-670f', ColumnFormat.id), '0d2fb383');
  });
  test('templates fill known fields', () {
    expect(Output.fill('Saved {label} {other}', {'label': 'x'}), 'Saved x {other}');
  });
  test('JSON output is one object with a versioned schema', () {
    final out = StringBuffer();
    make(json: true, out: out).render(ActionRegistry.byName['version']!, {'version': '1'});
    final decoded = jsonDecode(out.toString()) as Map;
    expect(decoded['schema'], 'warpgate.version/1');
    expect(decoded['version'], '1');
  });
  test('JSON errors go to stderr as JSON', () {
    final out = StringBuffer();
    final err = StringBuffer();
    make(json: true, out: out, err: err).failure(const ActionFailure('nope', kind: ExitKind.notFound, hint: 'h'));
    expect(out.toString(), isEmpty);
    final decoded = jsonDecode(err.toString()) as Map;
    expect(decoded['schema'], 'warpgate.error/1');
    expect(decoded['code'], 3);
    expect(decoded['kind'], 'notFound');
  });
  test('exit codes match the documented list', () {
    expect({for (final kind in ExitKind.values) kind.name: kind.code}, {
      'ok': 0,
      'general': 1,
      'usage': 2,
      'notFound': 3,
      'auth': 4,
      'hostKey': 5,
      'connection': 6,
      'partial': 7,
      'interrupted': 130,
    });
  });
  test('completion scripts exist for every shell', () {
    for (final shell in const ['bash', 'zsh', 'fish', 'powershell']) {
      expect(Completion.script(shell), contains('__complete'), reason: shell);
    }
  });
  test('completion finds commands and flags', () async {
    expect(await Completion.candidatesFor(['ho']), contains('hosts'));
    expect(await Completion.candidatesFor(['hosts', 'l']), contains('list'));
    expect(await Completion.candidatesFor(['ls', '--s']), contains('--sort'));
    expect(await Completion.candidatesFor(['ls', 'x', '--sort', 's']), contains('size'));
  });
}
