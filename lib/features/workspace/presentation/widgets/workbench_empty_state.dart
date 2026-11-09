import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';

class WorkbenchEmptyState extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);
    final keys = ref.watch(shortcutMapProvider);
    final registry = ref.read(commandRegistryProvider);
    if (hosts.isLoading) return const Center(child: WgSkeletonList(rows: 4));
    final none = hosts.value?.hosts.isEmpty ?? true;
    if (none) {
      return WgEmptyState(
        mark: const WgLogoMark(),
        title: 'Add a host to start',
        body: 'Save a server once with its address, user and key. Then open as many terminals and file panes on it as you need.',
        action: WgButton.primary(
          label: 'Add host',
          icon: WgIcons.plus,
          onPressed: () => GoRouter.of(context).go(Routes.hosts, extra: 'new'),
        ),
        secondary: WgButton.ghost(
          label: 'Import ~/.ssh/config',
          onPressed: () =>
              GoRouter.of(context).go(Routes.hosts, extra: 'import'),
        ),
      );
    }
    return WgEmptyState(
      icon: WgIcons.terminal,
      title: 'No sessions in this workspace',
      body: 'Open a terminal or a file browser. Every action is also in the command palette.',
      action: WgButton.primary(
        label: 'New terminal',
        icon: WgIcons.terminal,
        shortcut: keys['session.new'],
        onPressed: () => unawaited(registry.newSession()),
      ),
      secondary: WgButton(
        label: 'Command palette',
        shortcut: keys['palette.open'],
        onPressed: () => registry.run('palette.open'),
      ),
    );
  }
}
