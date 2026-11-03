import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/keys/domain/ssh_key.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/snippets/presentation/snippets_controller.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

import '../helpers/harness.dart';
import '../screens/render_screens_test.dart' show seedHosts;

final _when = DateTime(2026, 10, 28, 14, 5);

class FakeEndpoint extends FileEndpoint {
  new(this.label);

  @override
  final String label;

  static final Map<String, List<FileEntry>> tree = {
    '/home/ops': [
      for (final (name, dir, size) in [
        ('deploy', true, 0),
        ('logs', true, 0),
        ('releases', true, 0),
        ('.ssh', true, 0),
        ('backup-2026-10-27.tar.gz', false, 734003200),
        ('docker-compose.yml', false, 2140),
        ('notes.md', false, 913),
        ('.bashrc', false, 3771),
      ])
        FileEntry(
          name: name,
          path: '/home/ops/$name',
          isDirectory: dir,
          size: size,
          modified: _when,
          mode: dir ? 0x1ED : 0x1A4,
          owner: 'ops',
          group: 'ops',
        ),
    ],
  };

  @override
  bool get isLocal => false;

  @override
  p.Context get paths => p.posix;

  @override
  Future<String> home() async => '/home/ops';

  @override
  Future<List<FileEntry>> list(String directory) async =>
      tree[directory] ?? const [];

  @override
  Future<FileEntry?> stat(String path) async =>
      FileEntry(name: p.posix.basename(path), path: path, isDirectory: true);

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> removeEmptyDirectory(String path) async {}

  @override
  Future<void> setMode(String path, int mode) async {}

  @override
  Stream<Uint8List> read(String path, {int offset = 0}) => const Stream.empty();

  @override
  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  }) async {}
}

class _FixedFrame extends WindowFrameController {
  @override
  WindowFrame build() => const WindowFrame();
}

class FakeResolver extends EndpointResolver {
  new(super.ref);

  @override
  Future<FileEndpoint> resolve(String? hostId) async =>
      FakeEndpoint(hostId ?? 'This device');
}

final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const sizes = [Size(900, 600), Size(1280, 800), Size(1920, 1080)];

Future<ProviderContainer> start(
  WidgetTester tester,
  Size size,
  Brightness brightness,
) async {
  for (final channel in ['window_manager', 'warpgate/window']) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (_) async => null,
    );
  }
  final container = await pumpApp(
    tester,
    size: size,
    overrides: [
      sessionAutoStartProvider.overrideWithValue(false),
      windowFrameProvider.overrideWith(_FixedFrame.new),
      endpointResolverProvider.overrideWith(FakeResolver.new),
    ],
  );
  container.read(settingsProvider.notifier).update({
    'themeMode': brightness.name,
    'defaultRemotePath': '/home/ops',
  });
  await seedHosts(container);
  return container;
}

Future<void> fakeTerminals(ProviderContainer container) async {
  final sessions = container.read(terminalSessionsProvider);
  for (final session in sessions.all) {
    session.status.value = const LinkStatus(LinkState.connected);
    session.terminal.write(
      'Last login: Tue Oct 28 14:02:11 2026 from 10.0.0.8\r\n'
      r'ops@prod-db-1:~$ systemctl status postgresql --no-pager'
      '\r\n'
      '\x1b[32m●\x1b[0m postgresql.service - PostgreSQL RDBMS\r\n'
      '     Active: \x1b[32mactive (running)\x1b[0m since Mon 2026-10-27\r\n'
      r'ops@prod-db-1:~$ ',
    );
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.settleFor();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('screens/$name.png'),
  );
}

void main() {
  for (final size in sizes) {
    for (final brightness in Brightness.values) {
      final tag =
          '${size.width.toInt()}x${size.height.toInt()}_${brightness.name}';

      testWidgets('session view $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        container.read(workbenchProvider.notifier)
          ..openPane(
            const SshTerminalContent(
              hostId: 'prod-db-1',
              tmuxSession: 'ops',
              files: AttachedFiles(open: true, path: '/home/ops'),
            ),
          )
          ..openPane(
            const SshTerminalContent(
              hostId: 'nas',
              files: AttachedFiles(
                open: true,
                dock: FilesDock.bottom,
                path: '/home/ops',
                ratio: 0.5,
              ),
            ),
            placement: PanePlacement.splitRight,
          );
        await tester.settleFor();
        await fakeTerminals(container);
        await shot(tester, 'session_$tag');
      });

      testWidgets('files $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        container
            .read(workbenchProvider.notifier)
            .openPane(
              const SftpContent(
                left: SftpSide(hostId: 'prod-api-1', path: '/home/ops'),
                right: SftpSide(hostId: 'nas', path: '/home/ops'),
              ),
            );
        await shot(tester, 'files_$tag');
      });

      testWidgets('hosts $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        container.read(routerProvider).go(Routes.hosts);
        await shot(tester, 'hosts_$tag');
      });

      testWidgets('transfers $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        container.read(transferQueueProvider.notifier).state = [
          TransferJob(
            id: '1',
            source: const TransferRef(
              hostId: 'prod-db-1',
              path: '/var/backups/pg.dump',
            ),
            target: const TransferRef(hostId: 'nas', path: '/tank/pg.dump'),
            name: 'pg.dump',
            createdAt: _when,
            status: TransferStatus.running,
            totalBytes: 8400000000,
            doneBytes: 5210000000,
            bytesPerSecond: 94000000,
            move: true,
          ),
          TransferJob(
            id: '2',
            source: const TransferRef(path: '/Users/me/site'),
            target: const TransferRef(hostId: 'prod-api-1', path: '/srv/site'),
            name: 'site',
            isDirectory: true,
            createdAt: _when,
            status: TransferStatus.failed,
            error: 'Permission denied',
            totalBytes: 48000000,
            doneBytes: 12000000,
          ),
        ];
        container.read(routerProvider).go(Routes.transfers);
        await shot(tester, 'transfers_$tag');
        container.read(transferQueueProvider.notifier).state = const [];
        await tester.settleFor();
      });

      testWidgets('snippets empty $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        container.read(routerProvider).go(Routes.snippets);
        await shot(tester, 'snippets_empty_$tag');
      });

      testWidgets('snippets filled $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        final snippets = container.read(snippetsProvider.notifier);
        await container.read(snippetsProvider.future);
        await snippets.save(
          name: 'Restart service',
          body: 'sudo systemctl restart {{service|nginx}}',
        );
        await snippets.save(name: 'Disk usage', body: 'df -h && du -sh /var/*');
        await snippets.save(
          name: 'Tail logs',
          body: 'journalctl -u {{unit}} -f --since "{{since|10 min ago}}"',
        );
        container.read(routerProvider).go(Routes.snippets);
        await shot(tester, 'snippets_filled_$tag');
      });

      testWidgets('keys $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        final store = container.read(documentStoreProvider);
        for (final (id, name, algorithm) in [
          ('k1', 'laptop', KeyAlgorithm.ed25519),
          ('k2', 'deploy bot', KeyAlgorithm.rsa),
        ]) {
          await store.put('keys', id, {
            'id': id,
            'name': name,
            'algorithm': algorithm.name,
            'publicKey':
                'ssh-${algorithm.name} AAAAC3NzaC1lZDI1NTE5AAAAIB4 $name',
            'fingerprint': 'SHA256:3fQ1sX9mJk2rT0vYc8Ld7eWbN5pHqZ4aGu6iOyRw0Mk',
            'createdAt': _when.toIso8601String(),
          });
        }
        container.invalidate(keysProvider);
        container.read(routerProvider).go(Routes.keys);
        await shot(tester, 'keys_$tag');
      });

      testWidgets('settings $tag', variant: mac, (tester) async {
        final container = await start(tester, size, brightness);
        container.read(routerProvider).go(Routes.settings);
        await shot(tester, 'settings_$tag');
      });
    }
  }
}
