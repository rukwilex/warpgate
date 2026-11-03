@Tags(['binary'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:warpgate_core/actions/registry.dart';

void main() {
  late Directory work;
  late String binary;
  late Map<String, String> env;

  Future<ProcessResult> run(List<String> args) => Process.run(binary, args, environment: env);

  setUpAll(() async {
    work = Directory.systemTemp.createTempSync('wgbin');
    binary = p.join(work.path, 'warpgate');
    final built = await Process.run(Platform.resolvedExecutable, ['compile', 'exe', 'bin/warpgate.dart', '-o', binary]);
    expect(built.exitCode, 0, reason: '${built.stderr}');
    final key = File(p.join(work.path, 'mk'))..writeAsStringSync(base64Encode(List.filled(32, 7)));
    await Process.run('chmod', ['600', key.path]);
    env = {
      'WARPGATE_HOME': p.join(work.path, 'home'),
      'WARPGATE_MASTER_KEY_FILE': key.path,
    };
  });

  tearDownAll(() => work.deleteSync(recursive: true));

  test('exit codes', () async {
    expect((await run(['--version'])).exitCode, 0);
    expect((await run(['nope'])).exitCode, 2);
    expect((await run(['hosts', 'show', 'nope', '--no-app'])).exitCode, 3);
    expect((await run(['exec', 'root@127.0.0.1:1', '--no-app', '--', 'true'])).exitCode, 6);
    expect((await run(['sessions', 'list', '--no-app'])).exitCode, 1);
  });

  test('help is the same both ways', () async {
    final one = await run(['hosts', 'add', '--help']);
    final two = await run(['help', 'hosts', 'add']);
    expect(one.exitCode, 0);
    expect(one.stdout, two.stdout);
  });

  test('destructive commands need --yes without a terminal', () async {
    await run(['hosts', 'add', 'gone', 'me@box', '--no-app']);
    final refused = await run(['hosts', 'rm', 'gone', '--no-app']);
    expect(refused.exitCode, 2);
    expect(refused.stderr.toString(), contains('--yes'));
    expect((await run(['hosts', 'show', 'gone', '--no-app'])).exitCode, 0);
    expect((await run(['hosts', 'rm', 'gone', '--no-app', '--yes'])).exitCode, 0);
    expect((await run(['hosts', 'show', 'gone', '--no-app'])).exitCode, 3);
  });

  test('no ANSI when piped, and --json has no extra text', () async {
    final human = await run(['version']);
    expect(human.stdout.toString(), isNot(contains('\x1B')));
    final json = await run(['version', '--json']);
    expect((jsonDecode(json.stdout as String) as Map)['schema'], 'warpgate.version/1');
  });

  test('JSON errors are JSON on stderr', () async {
    final result = await run(['hosts', 'show', 'nope', '--json', '--no-app']);
    expect(result.stdout, isEmpty);
    expect((jsonDecode(result.stderr as String) as Map)['code'], 3);
  });

  test('passwords and keys are not printed', () async {
    final process = await Process.start(binary, ['hosts', 'add', 'pw', 'me@box', '--auth', 'password', '--password-stdin', '--no-app', '--json'], environment: env);
    process.stdin.write('s3cret-value');
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    expect(await process.exitCode, 0);
    expect(out, isNot(contains('s3cret-value')));
    final show = await run(['hosts', 'show', 'pw', '--json', '--no-app']);
    expect(show.stdout.toString(), isNot(contains('s3cret-value')));
    final export = await run(['hosts', 'export', '--no-app']);
    expect(export.stdout.toString(), isNot(contains('s3cret-value')));
    final database = File(p.join(env['WARPGATE_HOME']!, 'warpgate.sqlite')).readAsBytesSync();
    expect(latin1.decode(database), isNot(contains('s3cret-value')));
  });

  test('data commands match their JSON schema', () async {
    await run(['groups', 'add', 'web', '--no-app']);
    await run(['hosts', 'add', 'schema', 'me@box:2200', '-g', 'web', '--tag', 'x', '--no-app']);
    await run(['forward', 'add', 'schema', '-D', '1080', '--no-app']);
    await run(['snippets', 'add', 'greet', 'echo {{who|you}}', '--no-app']);
    await run(['keys', 'generate', 'schema-key', '--no-app']);
    const commands = [
      ['hosts', 'list'],
      ['hosts', 'show', 'schema'],
      ['groups', 'list'],
      ['keys', 'list'],
      ['keys', 'export-public', 'schema-key'],
      ['known-hosts', 'list'],
      ['transfers', 'list'],
      ['forward', 'list'],
      ['snippets', 'list'],
      ['layouts', 'list'],
      ['workspaces', 'list'],
      ['settings', 'list'],
      ['settings', 'get', 'accent'],
      ['settings', 'set', 'accent', 'teal'],
      ['mcp', 'status'],
      ['version'],
    ];
    for (final words in commands) {
      final result = await run([...words, '--json', '--no-app']);
      expect(result.exitCode, 0, reason: '$words ${result.stderr}');
      final decoded = (jsonDecode(result.stdout as String) as Map).cast<String, Object?>();
      final name = decoded['schema']! as String;
      final action = ActionRegistry.byName[name.substring('warpgate.'.length, name.length - 2)]!;
      expect(action.cli, startsWith(words.first == 'version' ? 'version' : words.first));
      expect(Shape.validate(decoded, action.result), isEmpty, reason: '$words');
    }
  });

  test('backup round trip, wrong passphrase refused', () async {
    final file = p.join(work.path, 'b.backup');
    Future<ProcessResult> withPass(List<String> args, String pass) async {
      final process = await Process.start(binary, args, environment: env);
      process.stdin.write(pass);
      await process.stdin.close();
      final out = await process.stdout.transform(utf8.decoder).join();
      final err = await process.stderr.transform(utf8.decoder).join();
      return ProcessResult(process.pid, await process.exitCode, out, err);
    }

    expect((await withPass(['backup', 'export', file, '--passphrase-stdin', '--no-app'], 'pp')).exitCode, 0);
    expect(File(file).readAsStringSync(), isNot(contains('schema')));
    expect((await withPass(['backup', 'import', file, '--passphrase-stdin', '--yes', '--no-app'], 'wrong')).exitCode, 1);
    expect((await withPass(['backup', 'import', file, '--passphrase-stdin', '--yes', '--no-app'], 'pp')).exitCode, 0);
  });

  test('install and uninstall make and remove a link to the binary', () async {
    final place = Directory(p.join(work.path, 'bin'))..createSync();
    final extra = {...env, 'WARPGATE_INSTALL_DIR': place.path};
    final installed = await Process.run(binary, ['--install', '--json'], environment: extra);
    expect(installed.exitCode, 0, reason: '${installed.stderr}');
    final link = Link(p.join(place.path, 'warpgate'));
    expect(link.existsSync(), isTrue);
    expect(link.resolveSymbolicLinksSync(), File(binary).resolveSymbolicLinksSync());
    final through = await Process.run(link.path, ['version'], environment: extra);
    expect(through.stdout, 'warpgate 1.0.0\n');
    expect((await Process.run(binary, ['--install'], environment: extra)).exitCode, 0);
    final refused = await Process.run(binary, ['uninstall'], environment: extra);
    expect(refused.exitCode, 2);
    expect((await Process.run(binary, ['uninstall', '--yes'], environment: extra)).exitCode, 0);
    expect(link.existsSync(), isFalse);
  }, skip: Platform.isWindows);

  test('a stale or broken key file is refused', () async {
    final loose = File(p.join(work.path, 'loose'))..writeAsStringSync(base64Encode(List.filled(32, 1)));
    await Process.run('chmod', ['644', loose.path]);
    final process = await Process.start(
      binary,
      ['hosts', 'add', 'loose', 'me@box', '--auth', 'password', '--password-stdin', '--no-app'],
      environment: {...env, 'WARPGATE_MASTER_KEY_FILE': loose.path},
    );
    process.stdin.write('x');
    await process.stdin.close();
    expect(await process.exitCode, 1);
  }, skip: Platform.isWindows);
}
