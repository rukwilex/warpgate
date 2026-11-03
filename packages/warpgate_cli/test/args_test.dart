import 'package:test/test.dart';
import 'package:warpgate_cli/warpgate_cli.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

Matcher usage() => throwsA(isA<ActionFailure>().having((f) => f.kind, 'kind', ExitKind.usage));

void main() {
  test('finds the longest command and its arguments', () {
    final parsed = ArgParser.parse(['hosts', 'add', 'prod', 'me@box', '-g', 'web']);
    expect(parsed.action!.name, 'hosts.add');
    expect(parsed.values['label'], 'prod');
    expect(parsed.values['group'], 'web');
  });
  test('nested groups', () {
    expect(ArgParser.parse(['mcp', 'token', 'show']).action!.name, 'mcp.token.show');
  });
  test('global flags work before and after the command', () {
    final before = ArgParser.parse(['--json', '--profile', 'x', 'hosts', 'list']);
    expect(before.globals.json, isTrue);
    expect(before.globals.profile, 'x');
    final after = ArgParser.parse(['hosts', 'list', '--json', '--no-app', '-y', '--profile=z']);
    expect(after.globals.json, isTrue);
    expect(after.globals.noApp, isTrue);
    expect(after.globals.yes, isTrue);
    expect(after.globals.profile, 'z');
  });
  test('short flags cluster', () {
    final parsed = ArgParser.parse(['ls', '-la', 'prod:/tmp']);
    expect(parsed.values['long'], isTrue);
    expect(parsed.values['all'], isTrue);
  });
  test('attached and repeated values', () {
    final parsed = ArgParser.parse(['ssh', '-L8080:a:80', '-L', '81:b:81', 'prod']);
    expect(parsed.values['local-forward'], ['8080:a:80', '81:b:81']);
  });
  test('ssh keeps flags that belong to the remote command', () {
    final parsed = ArgParser.parse(['ssh', 'prod', 'ls', '-la', '--help', '-v']);
    expect(parsed.values['command'], ['ls', '-la', '--help', '-v']);
    expect(parsed.globals.help, isFalse);
    expect(parsed.globals.verbose, isFalse);
  });
  test('exec splits on --', () {
    final parsed = ArgParser.parse(['exec', '@web', '--parallel', '4', '--', 'df', '-h']);
    expect(parsed.values['targets'], '@web');
    expect(parsed.values['parallel'], '4');
    expect(parsed.values['command'], ['df', '-h']);
  });
  test('exec without -- still works', () {
    expect(ArgParser.parse(['exec', 'a', 'uptime', '-p']).values['command'], ['uptime', '-p']);
  });
  test('exec needs a command', () {
    expect(() => ArgParser.parse(['exec', 'a']), usage());
  });
  test('broadcast takes many sessions', () {
    final parsed = ArgParser.parse(['broadcast', 'a', 'b', '--', 'hi']);
    expect(parsed.action!.name, 'broadcast.send');
    expect(parsed.values['sessions'], ['a', 'b']);
    expect(parsed.values['text'], ['hi']);
  });
  test('broadcast toggle is its own command', () {
    expect(ArgParser.parse(['broadcast', 'toggle']).action!.name, 'broadcast.toggle');
  });
  test('cp takes many paths', () {
    expect(ArgParser.parse(['cp', '-r', 'a', 'b', 'c:/d']).values['source'], ['a', 'b', 'c:/d']);
  });
  test('files aliases reach the same action', () {
    expect(ArgParser.parse(['files', 'ls', 'x:/']).action!.name, 'files.ls');
    expect(ArgParser.parse(['ls', 'x:/']).action!.name, 'files.ls');
  });
  test('--install works as a flag', () {
    expect(ArgParser.parse(['--install']).action!.name, 'install');
    expect(ArgParser.parse(['--install', '--json']).globals.json, isTrue);
  });
  test('defaults fill in', () {
    expect(ArgParser.parse(['ls', 'x:/']).values['sort'], 'name');
  });
  test('usage errors', () {
    expect(() => ArgParser.parse(['hosts', 'add', 'only-label']), usage());
    expect(() => ArgParser.parse(['ls', 'x', 'y']), usage());
    expect(() => ArgParser.parse(['ls', 'x', '--sort', 'nope']), usage());
    expect(() => ArgParser.parse(['ls', 'x', '--nope']), usage());
    expect(() => ArgParser.parse(['ls', 'x', '--sort']), usage());
    expect(() => ArgParser.parse(['panes', 'focus', 'sideways']), usage());
    expect(() => ArgParser.parse(['--profile']), usage());
  });
  test('typos suggest the closest command', () {
    String hint(List<String> argv) {
      try {
        ArgParser.parse(argv);
      } on ActionFailure catch (failure) {
        return failure.hint ?? '';
      }
      return '';
    }

    expect(hint(['hsots']), contains('warpgate hosts'));
    expect(hint(['hosts', 'lst']), contains('warpgate hosts list'));
    expect(hint(['ls', 'x', '--sot', 'name']), contains('--sort'));
  });
  test('a group alone shows its help', () {
    expect(ArgParser.parse(['hosts']).group, 'hosts');
  });
  test('Durations', () {
    expect(Durations.parse('30s'), const Duration(seconds: 30));
    expect(Durations.parse('5m'), const Duration(minutes: 5));
    expect(Durations.parse('10'), const Duration(seconds: 10));
    expect(Durations.parse(null), isNull);
    expect(() => Durations.parse('soon'), usage());
  });
}
