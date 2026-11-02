@Tags(['screens'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

import '../helpers/harness.dart';

Future<void> seedHosts(ProviderContainer container) async {
  final hosts = container.read(hostsProvider.notifier);
  await container.read(hostsProvider.future);
  final prod = await hosts.addGroup('prod cluster');
  final lab = await hosts.addGroup('home lab');
  const user = 'ops';
  for (final (label, address, group, tags) in [
    ('prod-db-1', '10.0.4.21', prod.id, ['db']),
    ('prod-db-2', '10.0.4.22', prod.id, ['db']),
    ('prod-api-1', '10.0.5.11', prod.id, ['api']),
    ('edge-lb-2', 'edge-lb-2.internal', prod.id, <String>[]),
    ('nas', '192.168.1.20', lab.id, ['storage']),
    ('pi-hole', '192.168.1.3', lab.id, <String>[]),
    ('bastion', '203.0.113.10', null, <String>[]),
  ]) {
    await hosts.saveHost(
      Host(
        id: label,
        label: label,
        address: address,
        username: user,
        groupId: group,
        tags: tags,
        tmuxPersistence: label.startsWith('prod'),
        mcpPermission: label == 'prod-api-1'
            ? McpPermission.readOnly
            : McpPermission.off,
        jumpHostId: label.startsWith('prod') ? 'bastion' : null,
      ),
    );
  }
}

class _FixedFrame extends WindowFrameController {
  new(this.frame);

  final WindowFrame frame;

  @override
  WindowFrame build() => frame;
}

void main() {
  final skip = Platform.environment['WARPGATE_RENDER_SCREENS'] == null
      ? 'Set WARPGATE_RENDER_SCREENS=1 and pass --update-goldens to render review screenshots'
      : null;
  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('screens ${brightness.name}', skip: skip != null, (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(settingsProvider.notifier).update({
        'themeMode': brightness.name,
      });
      await seedHosts(container);
      final router = container.read(routerProvider);
      Future<void> shot(String name) async {
        await tester.settleFor();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('out/${brightness.name}_$name.png'),
        );
      }

      await shot('workbench_empty');
      router.go(Routes.hosts);
      await shot('hosts');
      router.go(Routes.hosts, extra: 'prod-db-1');
      await shot('host_editor');
      rootNavigatorKey.currentState!.pop();
      router.go(Routes.keys);
      await shot('keys');
      router.go(Routes.multiExec);
      await shot('multi_exec');
      router.go(Routes.settings);
      await shot('settings');
      router.go(Routes.workbench);
      container.read(paletteProvider.notifier).open(PaletteMode.commands);
      await shot('palette');
      container.read(paletteProvider.notifier).close();
      await tester.settleFor();
    });
  }

  testWidgets('transfers with jobs', skip: skip != null, (tester) async {
    final now = DateTime(2026, 11, 2, 21, 40);
    final container = await pumpApp(tester);
    await seedHosts(container);
    final queue = container.read(transferQueueProvider.notifier)
      ..state = [
        TransferJob(
          id: '1',
          source: const TransferRef(
            hostId: 'prod-db-1',
            path: '/var/backups/pg.dump',
          ),
          target: const TransferRef(hostId: 'nas', path: '/tank/pg.dump'),
          name: 'pg.dump',
          createdAt: now,
          status: TransferStatus.running,
          totalBytes: 8400000000,
          doneBytes: 5210000000,
          bytesPerSecond: 94000000,
        ),
        TransferJob(
          id: '2',
          source: const TransferRef(path: '/Users/me/site'),
          target: const TransferRef(hostId: 'prod-api-1', path: '/srv/site'),
          name: 'site',
          isDirectory: true,
          createdAt: now,
          status: TransferStatus.paused,
          totalBytes: 48000000,
          doneBytes: 12000000,
          filesTotal: 412,
          filesDone: 96,
        ),
        TransferJob(
          id: '3',
          source: const TransferRef(hostId: 'edge-lb-2', path: '/etc/nginx'),
          target: const TransferRef(path: '/tmp/nginx'),
          name: 'nginx',
          isDirectory: true,
          createdAt: now,
          status: TransferStatus.failed,
          error: 'Permission denied',
          totalBytes: 200000,
          doneBytes: 80000,
        ),
        TransferJob(
          id: '4',
          source: const TransferRef(
            hostId: 'nas',
            path: '/tank/iso/debian.iso',
          ),
          target: const TransferRef(hostId: 'pi-hole', path: '/tmp/debian.iso'),
          name: 'debian.iso',
          createdAt: now,
          status: TransferStatus.completed,
          totalBytes: 650000000,
          doneBytes: 650000000,
        ),
      ];
    container.read(routerProvider).go(Routes.transfers);
    await tester.settleFor();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/dark_transfers.png'),
    );
    queue.state = const [];
    await tester.settleFor();
  });

  testWidgets('phone', skip: skip != null, (tester) async {
    final container = await pumpApp(tester, size: const Size(390, 844));
    await seedHosts(container);
    container.read(routerProvider).go(Routes.hosts);
    await tester.settleFor();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/phone_hosts.png'),
    );
    container.read(routerProvider).go(Routes.settings);
    await tester.settleFor();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/phone_settings.png'),
    );
  });

  for (final (chrome, platform) in [
    (WindowChrome.mac, TargetPlatform.macOS),
    (WindowChrome.windows, TargetPlatform.windows),
  ]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final (state, frame) in [
        ('active', const WindowFrame()),
        ('inactive', const WindowFrame(focused: false)),
        ('maximized', const WindowFrame(maximized: true)),
      ]) {
        testWidgets(
          'title bar ${chrome.name} ${brightness.name} $state',
          skip: skip != null,
          variant: TargetPlatformVariant.only(platform),
          (tester) async {
            for (final channel in ['window_manager', 'warpgate/window']) {
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                MethodChannel(channel),
                (_) async => null,
              );
            }
            final container = await pumpApp(
              tester,
              overrides: [
                windowChromeProvider.overrideWithValue(chrome),
                windowFrameProvider.overrideWith(() => _FixedFrame(frame)),
              ],
            );
            container.read(settingsProvider.notifier).update({
              'themeMode': brightness.name,
            });
            await seedHosts(container);
            container.read(routerProvider).go(Routes.hosts);
            container.read(workbenchProvider.notifier)
              ..openPane(const SshTerminalContent(hostId: 'prod-db-1'))
              ..openPane(const SshTerminalContent(hostId: 'nas'));
            await tester.settleFor();
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'out/titlebar_${chrome.name}_${brightness.name}_$state.png',
              ),
            );
          },
        );
      }
    }
  }
}
