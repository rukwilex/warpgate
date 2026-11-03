@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';

void main() {
  final environment = Platform.environment;
  final host = environment['WARPGATE_TEST_SSH_HOST'] ?? '127.0.0.1';
  final port = environment['WARPGATE_TEST_SSH_PORT'];
  final user = environment['WARPGATE_TEST_SSH_USER'];
  final key = environment['WARPGATE_TEST_SSH_KEY'];
  final skip = port == null || user == null || key == null
      ? 'Set WARPGATE_TEST_SSH_PORT, _USER and _KEY. tool/cli_test_server.sh prints them'
      : null;

  late Directory work;
  late String binary;
  late Map<String, String> env;
  final remote = '/tmp/wg-cli-${Random().nextInt(1 << 32)}';

  Future<ProcessResult> run(List<String> args, {Map<String, String>? extra}) =>
      Process.run(binary, ['--no-app', ...args], environment: {...env, ...?extra});

  Future<void> ok(List<String> args) async {
    final result = await run(args);
    expect(result.exitCode, 0, reason: '$args\n${result.stdout}\n${result.stderr}');
  }

  setUpAll(() async {
    if (skip != null) return;
    work = Directory.systemTemp.createTempSync('wgint');
    binary = p.join(work.path, 'warpgate');
    final built = await Process.run(Platform.resolvedExecutable, ['compile', 'exe', 'bin/warpgate.dart', '-o', binary]);
    expect(built.exitCode, 0, reason: '${built.stderr}');
    final master = File(p.join(work.path, 'mk'))..writeAsStringSync(base64Encode(List.filled(32, 9)));
    await Process.run('chmod', ['600', master.path]);
    env = {
      'WARPGATE_HOME': p.join(work.path, 'home'),
      'WARPGATE_MASTER_KEY_FILE': master.path,
      'HOME': work.path,
    };
    await ok(['keys', 'import', key!, '--name', 'test']);
    await ok(['hosts', 'add', 'a', '$user@$host:$port', '--key', 'test']);
    await ok(['hosts', 'add', 'b', '$user@$host:$port', '--key', 'test']);
    await ok(['groups', 'add', 'pair']);
    await ok(['groups', 'move', 'pair', 'a', 'b']);
  });

  tearDownAll(() async {
    if (skip != null) return;
    await run(['exec', 'a', '--no-app', '--', 'rm -rf $remote']);
    work.deleteSync(recursive: true);
  });

  test('an unknown host key is refused without a terminal, then trusted', () async {
    final refused = await run(['exec', 'a', '--no-app', '--', 'true']);
    expect(refused.exitCode, 5, reason: '${refused.stderr}');
    await ok(['known-hosts', 'trust', 'a', '--yes']);
    final accepted = await run(['exec', 'a', '--no-app', '--', 'mkdir -p $remote']);
    expect(accepted.exitCode, 0, reason: '${accepted.stderr}');
  }, skip: skip);

  test('a changed host key is refused and the saved key is kept', () async {
    final store = SqliteDocumentStore.open(p.join(env['WARPGATE_HOME']!, 'warpgate.sqlite'));
    final endpoint = '$host:$port';
    final saved = (await store.get('known_hosts', endpoint))!;
    await store.put('known_hosts', endpoint, {...saved, 'fingerprint': 'SHA256:not-the-key'});
    final result = await run(['exec', 'a', '--no-app', '--', 'true']);
    expect(result.exitCode, 5);
    expect(result.stderr.toString(), contains('changed'));
    expect((await store.get('known_hosts', endpoint))!['fingerprint'], 'SHA256:not-the-key');
    await store.put('known_hosts', endpoint, saved);
    store.close();
  }, skip: skip);

  test('exec returns the remote exit code and streams both outputs', () async {
    final result = await run(['exec', 'a', '--no-app', '--', 'echo out; echo err >&2; exit 42']);
    expect(result.exitCode, 42);
    expect(result.stdout, 'out\n');
    expect(result.stderr, 'err\n');
  }, skip: skip);

  test('exec on one host feeds stdin', () async {
    final process = await Process.start(binary, ['exec', 'a', '--no-app', '--', 'cat'], environment: env);
    process.stdin.write('piped');
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    expect(await process.exitCode, 0);
    expect(out, 'piped');
  }, skip: skip);

  test('exec times out', () async {
    final result = await run(['exec', 'a', '--no-app', '--timeout', '1s', '--', 'sleep 10']);
    expect(result.exitCode, 1);
  }, skip: skip);

  test('multi-host exec in JSON', () async {
    final result = await run(['exec', '@pair', '--json', '--no-app', '--', 'echo hi']);
    expect(result.exitCode, 0);
    final decoded = jsonDecode(result.stdout as String) as Map;
    expect(decoded['succeeded'], 2);
    expect((decoded['results'] as List).length, 2);
  }, skip: skip);

  test('multi-host failure exits 7, and stop-on-failure stops', () async {
    final partial = await run(['exec', 'a,b', '--no-app', '--', 'exit 3']);
    expect(partial.exitCode, 7);
    final stopped = await run(['exec', 'a,b', '--stop-on-failure', '--json', '--no-app', '--', 'exit 3']);
    expect(stopped.exitCode, 7);
    final results = (jsonDecode(stopped.stdout as String) as Map)['results'] as List;
    expect((results[1] as Map)['error'], contains('Not run'));
  }, skip: skip);

  test('ssh with a command', () async {
    final result = await run(['ssh', 'a', '--no-app', 'echo', 'hello']);
    expect(result.stdout, 'hello\n');
    expect(result.exitCode, 0);
  }, skip: skip);

  test('interactive ssh has a PTY and passes the exit code', () async {
    final args = Platform.isMacOS
        ? ['-q', '/dev/null', binary, 'ssh', 'a', '--no-app']
        : ['-qec', '$binary ssh a --no-app', '/dev/null'];
    final process = await Process.start('script', args, environment: {...env, 'TERM': 'xterm'});
    final out = StringBuffer();
    process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen(out.write);
    await Future<void>.delayed(const Duration(seconds: 2));
    process.stdin.writeln('test -t 0 && echo tty-yes-\$((40+2))');
    await Future<void>.delayed(const Duration(seconds: 1));
    process.stdin.writeln('exit 9');
    await process.stdin.flush();
    final code = await process.exitCode.timeout(const Duration(seconds: 15));
    expect(out.toString(), contains('tty-yes-42'));
    if (!Platform.isMacOS) expect(code, 9);
  }, skip: skip);

  test('ls, put, get, cat, stat, mkdir, chmod, mv, rm, find, du', () async {
    final folder = Directory(p.join(work.path, 'src', 'sub'))..createSync(recursive: true);
    File(p.join(work.path, 'src', 'one.txt')).writeAsStringSync('one');
    File(p.join(folder.path, 'two.log')).writeAsStringSync('two2');
    final refused = await run(['put', p.join(work.path, 'src'), 'a:$remote/up']);
    expect(refused.exitCode, 2);
    await ok(['put', '-r', p.join(work.path, 'src'), 'a:$remote/up']);
    final listing = await run(['ls', 'a:$remote/up']);
    expect(listing.stdout, 'one.txt\nsub/\n');
    final tree = await run(['ls', '--tree', 'a:$remote/up']);
    expect(tree.stdout, 'one.txt\nsub/\n  two.log\n');
    final long = await run(['ls', '-l', 'a:$remote/up', '--json']);
    expect(((jsonDecode(long.stdout as String) as Map)['entries'] as List).length, 2);
    final cat = await run(['cat', 'a:$remote/up/one.txt']);
    expect(cat.stdout, 'one');
    final found = await run(['find', 'a:$remote/up', '*.log', '--json']);
    expect(((jsonDecode(found.stdout as String) as Map)['matches'] as List).length, 1);
    final du = await run(['du', 'a:$remote/up', '--json']);
    expect((jsonDecode(du.stdout as String) as Map)['total'], 7);
    await ok(['mkdir', '-p', 'a:$remote/deep/er/still']);
    await ok(['chmod', '640', 'a:$remote/up/one.txt']);
    final stat = await run(['stat', 'a:$remote/up/one.txt', '--json']);
    expect(((jsonDecode(stat.stdout as String) as Map)['entry'] as Map)['mode'], '640');
    await ok(['mv', 'a:$remote/up/one.txt', '$remote/up/renamed.txt']);
    final down = p.join(work.path, 'down');
    await ok(['get', '-r', 'a:$remote/up', down]);
    expect(File(p.join(down, 'renamed.txt')).readAsStringSync(), 'one');
    expect(File(p.join(down, 'sub', 'two.log')).readAsStringSync(), 'two2');
    expect((await run(['rm', 'a:$remote/up'])).exitCode, 2);
    expect((await run(['rm', 'a:$remote/up', '--yes'])).exitCode, 2);
    await ok(['rm', '-r', '--yes', 'a:$remote/up']);
    expect((await run(['ls', 'a:$remote/up'])).exitCode, 3);
  }, skip: skip);

  test('put from stdin', () async {
    final process = await Process.start(binary, ['put', '-', 'a:$remote/stdin.txt', '--no-app'], environment: env);
    process.stdin.write('from stdin');
    await process.stdin.close();
    expect(await process.exitCode, 0);
    expect((await run(['cat', 'a:$remote/stdin.txt'])).stdout, 'from stdin');
  }, skip: skip);

  test('remote to remote copy, move and verify', () async {
    final bytes = List<int>.generate(300000, (i) => i * 7 & 255);
    final local = File(p.join(work.path, 'blob.bin'))..writeAsBytesSync(bytes);
    await ok(['cp', local.path, 'a:$remote/blob.bin']);
    await ok(['cp', '--verify', 'a:$remote/blob.bin', 'b:$remote/blob2.bin']);
    final back = p.join(work.path, 'back.bin');
    await ok(['cp', 'b:$remote/blob2.bin', back]);
    expect(File(back).readAsBytesSync(), bytes);
    await ok(['cp', '--move', 'b:$remote/blob2.bin', 'a:$remote/moved.bin']);
    expect((await run(['stat', 'b:$remote/blob2.bin'])).exitCode, 3);
    expect((await run(['stat', 'a:$remote/moved.bin'])).exitCode, 0);
  }, skip: skip);

  test('resume finishes a partial file without resending it', () async {
    final bytes = List<int>.generate(500000, (i) => i * 13 & 255);
    final local = File(p.join(work.path, 'res.bin'))..writeAsBytesSync(bytes);
    await ok(['cp', local.path, 'a:$remote/res.bin']);
    final partial = p.join(work.path, 'partial.bin');
    final marker = List<int>.filled(100000, 1);
    File(partial).writeAsBytesSync(marker);
    await ok(['cp', '--resume', 'a:$remote/res.bin', partial]);
    final result = File(partial).readAsBytesSync();
    expect(result.length, bytes.length);
    expect(result.sublist(0, 100000), marker);
    expect(result.sublist(100000), bytes.sublist(100000));
  }, skip: skip);

  test('verify catches a real mismatch after a bad resume', () async {
    final local = File(p.join(work.path, 'bad.bin'))..writeAsBytesSync(List<int>.generate(50000, (i) => i & 255));
    final target = p.join(work.path, 'bad-target.bin');
    await ok(['cp', local.path, 'a:$remote/bad.bin']);
    File(target).writeAsBytesSync(List<int>.filled(100, 1));
    final result = await run(['cp', '--resume', '--verify', 'a:$remote/bad.bin', target]);
    expect(result.exitCode, 1);
    expect(result.stderr.toString(), contains('checksum'));
  }, skip: skip);

  test('local port forward reaches the server', () async {
    final local = 21000 + Random().nextInt(4000);
    final process = await Process.start(
      binary,
      ['ssh', 'a', '-L', '$local:127.0.0.1:$port', '--no-app', 'sleep', '6'],
      environment: env,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final socket = await Socket.connect('127.0.0.1', local);
    final banner = await socket.cast<List<int>>().transform(utf8.decoder).first.timeout(const Duration(seconds: 5));
    expect(banner, startsWith('SSH-2.0'));
    socket.destroy();
    process.kill();
  }, skip: skip);

  test('dynamic forward speaks SOCKS5', () async {
    final local = 25000 + Random().nextInt(4000);
    final process = await Process.start(
      binary,
      ['ssh', 'a', '-D', '$local', '--no-app', 'sleep', '5'],
      environment: env,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final socket = await Socket.connect('127.0.0.1', local);
    socket.add([5, 1, 0]);
    final reply = await socket.first.timeout(const Duration(seconds: 5));
    expect(reply.sublist(0, 2), [5, 0]);
    socket.destroy();
    process.kill();
  }, skip: skip);

  test('jump host', () async {
    final result = await run(['ssh', 'b', '-J', 'a', '--no-app', 'echo', 'through']);
    expect(result.stdout, 'through\n', reason: '${result.stderr}');
  }, skip: skip);

  test('ssh-agent signs in without a saved key', () async {
    final socket = p.join(work.path, 'agent.sock');
    final agent = await Process.start('ssh-agent', ['-D', '-a', socket]);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final added = await Process.run('ssh-add', [key!], environment: {'SSH_AUTH_SOCK': socket});
    expect(added.exitCode, 0, reason: '${added.stderr}');
    final result = await run(
      ['exec', '$user@$host:$port', '--no-app', '--', 'echo agent-ok'],
      extra: {'SSH_AUTH_SOCK': socket},
    );
    expect(result.stdout, 'agent-ok\n', reason: '${result.stderr}');
    agent.kill();
  }, skip: skip);

  test('bad credentials exit 4', () async {
    final other = File(p.join(work.path, 'other'));
    await Process.run('ssh-keygen', ['-q', '-t', 'ed25519', '-N', '', '-f', other.path]);
    await ok(['keys', 'import', other.path, '--name', 'other']);
    await ok(['hosts', 'add', 'wrong', '$user@$host:$port', '--key', 'other']);
    final result = await run(['exec', 'wrong', '--no-app', '--', 'true']);
    expect(result.exitCode, 4);
  }, skip: skip);

  test('a closed port exits 6', () async {
    final result = await run(['exec', '$user@127.0.0.1:1', '--no-app', '--', 'true']);
    expect(result.exitCode, 6);
  }, skip: skip);

  test('snippets run with variables', () async {
    await ok(['snippets', 'add', 'hello', 'echo hello {{who|world}}']);
    expect((await run(['snippets', 'run', 'hello', '--on', 'a', '--var', 'who=me'])).stdout, 'hello me\n');
    expect((await run(['snippets', 'run', 'hello', '--on', 'a'])).stdout, 'hello world\n');
  }, skip: skip);

  test('mcp serve answers over stdio and honours host permissions', () async {
    await ok(['hosts', 'edit', 'a', '--mcp', 'full']);
    await ok(['settings', 'set', 'mcpAskBeforeMutating', 'false']);
    final process = await Process.start(binary, ['mcp', 'serve', '--no-app'], environment: env);
    final replies = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
    Future<Map<Object?, Object?>> call(int id, String method, Map<String, Object?> params) async {
      final reply = replies.first;
      process.stdin.writeln(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));
      return jsonDecode(await reply.timeout(const Duration(seconds: 15))) as Map;
    }

    final tools = await call(1, 'tools/list', {'_meta': {'io.modelcontextprotocol/protocolVersion': '2025-06-18'}});
    expect('$tools', contains('run_command'));
    final hosts = await call(2, 'tools/call', {'name': 'list_hosts', 'arguments': <String, Object?>{}});
    expect('$hosts', contains('"label": "a"'));
    expect('$hosts', isNot(contains('"label": "b"')));
    final runIt = await call(3, 'tools/call', {'name': 'run_command', 'arguments': {'host_id': 'a', 'command': 'echo from-mcp'}});
    expect('$runIt', contains('from-mcp'));
    final denied = await call(4, 'tools/call', {'name': 'run_command', 'arguments': {'host_id': 'b', 'command': 'echo no'}});
    expect('$denied', contains('no access'));
    await process.stdin.close();
    await process.exitCode;
  }, skip: skip);

  test('transfers are listed and can be cleared', () async {
    final list = await run(['transfers', 'list', '--json']);
    expect(((jsonDecode(list.stdout as String) as Map)['transfers'] as List), isNotEmpty);
    await ok(['transfers', 'clear']);
    final after = await run(['transfers', 'list', '--status', 'completed', '--json']);
    expect(((jsonDecode(after.stdout as String) as Map)['transfers'] as List), isEmpty);
  }, skip: skip);
}
