import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/ssh_agent_client.dart';
import 'package:warpgate_core/features/settings/data/settings_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

TransferJob job(TransferStatus status, {int? owner}) => TransferJob(
  id: 'x',
  source: const TransferRef(path: '/a'),
  target: const TransferRef(path: '/b'),
  name: 'a',
  createdAt: DateTime(2026),
  status: status,
  ownerPid: owner,
);

void main() {
  group('restore', () {
    test('a running app job goes back in the queue', () {
      final restored = TransferScheduler.restore([job(TransferStatus.running)], (_) => false);
      expect(restored.single.status, TransferStatus.queued);
    });
    test('a job of a live CLI process is left alone', () {
      final restored = TransferScheduler.restore([job(TransferStatus.running, owner: 9)], (_) => true);
      expect(restored.single.status, TransferStatus.running);
      expect(restored.single.ownerPid, 9);
    });
    test('a job whose CLI process died becomes paused', () {
      final restored = TransferScheduler.restore([job(TransferStatus.running, owner: 9)], (_) => false);
      expect(restored.single.status, TransferStatus.paused);
      expect(restored.single.ownerPid, isNull);
    });
    test('owner and verify survive JSON', () {
      final back = TransferJob.fromJson(job(TransferStatus.running, owner: 9).toJson());
      expect(back.ownerPid, 9);
    });
  });

  group('agent wire format', () {
    Uint8List string(List<int> value) {
      final size = ByteData(4)..setUint32(0, value.length);
      return Uint8List.fromList([...size.buffer.asUint8List(), ...value]);
    }

    test('identities answer parses', () {
      final blob = string('ssh-ed25519'.codeUnits);
      final count = ByteData(4)..setUint32(0, 1);
      final framed = SshAgentClient.frame([
        12,
        ...count.buffer.asUint8List(),
        ...string(blob),
        ...string('me@box'.codeUnits),
      ]);
      final keys = SshAgentClient.parseIdentities(framed);
      expect(keys.single.comment, 'me@box');
      expect(keys.single.algorithm, 'ssh-ed25519');
    });
    test('a failure answer is rejected', () {
      expect(
        () => SshAgentClient.parseIdentities(SshAgentClient.frame([5])),
        throwsFormatException,
      );
    });
  });

  group('settings', () {
    test('coerce checks the type of each setting', () {
      expect(SettingsStore.coerce('transferConcurrency', '5'), 5);
      expect(SettingsStore.coerce('copyOnSelect', 'true'), true);
      expect(SettingsStore.coerce('themeMode', 'dark'), 'dark');
      expect(() => SettingsStore.coerce('themeMode', 'pink'), throwsA(isA<SettingValueError>()));
      expect(() => SettingsStore.coerce('copyOnSelect', 'x'), throwsA(isA<SettingValueError>()));
      expect(() => SettingsStore.field('nope'), throwsA(isA<SettingValueError>()));
    });
    test('every listed setting exists on AppSettings', () {
      final json = const AppSettings().toJson();
      for (final field in SettingsStore.fields) {
        expect(json.containsKey(field.key), isTrue, reason: field.key);
      }
    });
    test('patch only changes what it is given', () async {
      final root = Directory.systemTemp.createTempSync('wg');
      final store = SqliteDocumentStore.open(p.join(root.path, 'a.sqlite'));
      final settings = SettingsStore(store);
      await settings.patch({'mcpPort': 9000});
      final next = await settings.patch({'copyOnSelect': true});
      expect(next.mcpPort, 9000);
      expect(next.copyOnSelect, isTrue);
      store.close();
      root.deleteSync(recursive: true);
    });
  });

  group('failures map to exit codes', () {
    test('missing file', () {
      expect(
        Failures.classify(const FileOperationException('No such file or folder')).kind,
        ExitKind.notFound,
      );
    });
    test('socket errors', () {
      expect(Failures.classify(const SocketException('x')).kind, ExitKind.connection);
    });
  });

  test('runtime builds with a memory secret store', () async {
    final root = Directory.systemTemp.createTempSync('wg');
    final store = SqliteDocumentStore.open(p.join(root.path, 'a.sqlite'));
    final runtime = WarpgateRuntime(store: store, secrets: MemorySecretStore(), broker: InteractionBroker());
    await runtime.loadCatalog();
    expect(runtime.hosts.catalog.hosts, isEmpty);
    await runtime.close();
    store.close();
    root.deleteSync(recursive: true);
  });
}
