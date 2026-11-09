import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/ipc/ipc.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('wg'));
  tearDown(() => root.deleteSync(recursive: true));

  group('SqliteDocumentStore', () {
    test('round trips documents in order and handles unicode', () async {
      final store = SqliteDocumentStore.open(p.join(root.path, 'a.sqlite'));
      await store.put('c', '1', {'name': 'héllo ✓'}, at: DateTime(2020));
      await store.put('c', '2', {'name': 'b'}, at: DateTime(2021));
      expect((await store.get('c', '1'))!['name'], 'héllo ✓');
      expect((await store.all('c', newestFirst: true)).first['name'], 'b');
      await store.trim('c', 1);
      expect(await store.all('c'), hasLength(1));
      await store.delete('c', '2');
      expect(await store.get('c', '2'), isNull);
      store.close();
    });

    test('a failed transaction rolls back', () async {
      final store = SqliteDocumentStore.open(p.join(root.path, 'a.sqlite'));
      await expectLater(
        store.transaction(() async {
          await store.put('c', '1', {'a': 1});
          throw StateError('stop');
        }),
        throwsStateError,
      );
      expect(await store.get('c', '1'), isNull);
      store.close();
    });

    test('a second connection sees writes and data_version moves', () async {
      final path = p.join(root.path, 'a.sqlite');
      final one = SqliteDocumentStore.open(path);
      final two = SqliteDocumentStore.open(path);
      final before = await one.dataVersion();
      await two.put('c', '1', {'a': 1});
      expect(await one.dataVersion(), isNot(before));
      expect(await one.get('c', '1'), isNotNull);
      one.close();
      two.close();
    });
  });

  group('AppPaths', () {
    test('profiles get their own folder and keychain item', () {
      final paths = AppPaths.resolve(profile: 'work', environment: {'WARPGATE_HOME': '/x'});
      expect(paths.root, p.join('/x', 'profiles', 'work'));
      expect(paths.keychainAccount, 'warpgate.master-key.work');
    });
    test('WARPGATE_HOME wins over the platform folder', () {
      final paths = AppPaths.resolve(environment: {'WARPGATE_HOME': '/x'}, platformRoot: '/y');
      expect(paths.root, '/x');
    });
  });

  group('IPC', () {
    test('answers, reports failures, and is private', () async {
      final paths = AppPaths(root.path);
      final server = IpcServer(paths, (method, params) async {
        if (method == 'boom') {
          throw const ActionFailure('nope', kind: ExitKind.notFound, hint: 'try');
        }
        return {'echo': params['value']};
      });
      await server.start();
      final client = await IpcClient.connect(paths);
      expect(client, isNotNull);
      expect((await client!.call('x', {'value': 3}))['echo'], 3);
      await expectLater(
        client.call('boom'),
        throwsA(isA<ActionFailure>()
            .having((f) => f.kind, 'kind', ExitKind.notFound)
            .having((f) => f.hint, 'hint', 'try')),
      );
      if (!Platform.isWindows) {
        expect(FileStat.statSync(paths.ipcToken).mode & 511, 384);
        expect(FileStat.statSync(paths.ipcDirectory).mode & 511, 448);
        expect(FileStat.statSync(paths.ipcSocket).mode & 511, 384);
      }
      await client.close();
      await server.stop();
      expect(await IpcClient.connect(paths), isNull);
    });

    test('a request the app never answers times out instead of blocking every later call', () async {
      final paths = AppPaths(root.path);
      final server = IpcServer(paths, (method, params) async {
        if (method == 'hang') await Completer<void>().future;
        return {'ok': true};
      });
      await server.start();
      final client = (await IpcClient.connect(paths))!;
      await expectLater(
        client.call('hang', const {}, const Duration(milliseconds: 200)),
        throwsA(isA<IpcUnavailable>()),
      );
      await expectLater(client.call('ping'), throwsA(isA<IpcUnavailable>()));
      final fresh = (await IpcClient.connect(paths))!;
      expect((await fresh.call('ping'))['ok'], isTrue);
      await fresh.close();
      await server.stop();
    });

    test('a malformed line closes that client and the server keeps serving', () async {
      final paths = AppPaths(root.path);
      final server = IpcServer(paths, (method, params) async => {'ok': true});
      await server.start();
      final raw = await Socket.connect(InternetAddress(paths.ipcSocket, type: InternetAddressType.unix), 0);
      raw.writeln('not json');
      await raw.drain<void>().timeout(const Duration(seconds: 5));
      final client = (await IpcClient.connect(paths))!;
      expect((await client.call('x'))['ok'], isTrue);
      await client.close();
      await server.stop();
    }, skip: Platform.isWindows ? 'Unix sockets only' : null);

    test('a wrong token gets nothing', () async {
      final paths = AppPaths(root.path);
      var calls = 0;
      final server = IpcServer(paths, (method, params) async {
        calls++;
        return const {};
      });
      await server.start();
      File(paths.ipcToken).writeAsStringSync('wrong');
      expect(await IpcClient.connect(paths), isNull);
      expect(calls, 0);
      await server.stop();
    });

    test('a long path falls back to a short socket in the runtime folder', () {
      final long = AppPaths('/${'x' * 120}', runtimeDirectories: const ['/run/user/1']);
      expect(long.ipcSocket, startsWith('/run/user/1/wg-'));
      expect(long.ipcSocket.length, lessThanOrEqualTo(AppPaths.maxSocketPath));
      expect(const AppPaths('/short').ipcSocket, '/short/ipc/warpgate.sock');
    });

    test('a failed start leaves no token behind', () async {
      final paths = AppPaths('${root.path}/${'x' * 120}');
      final server = IpcServer(paths, (method, params) async => const {});
      await expectLater(server.start(), throwsA(isA<IpcUnavailable>()));
      expect(File(paths.ipcToken).existsSync(), isFalse);
      expect(await IpcClient.connect(paths), isNull);
    }, skip: Platform.isWindows);

    test('calls in a row keep their order', () async {
      final paths = AppPaths(root.path);
      final server = IpcServer(paths, (method, params) async => {'v': params['v']});
      await server.start();
      final client = (await IpcClient.connect(paths))!;
      final results = await Future.wait([
        for (var i = 0; i < 20; i++) client.call('x', {'v': i}),
      ]);
      expect([for (final item in results) item['v']], List.generate(20, (i) => i));
      await client.close();
      await server.stop();
    });
  });
}
