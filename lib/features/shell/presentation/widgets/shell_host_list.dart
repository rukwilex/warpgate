import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/host_groups.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class ShellHostList extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(hostsProvider);
    final links = ref.watch(hostLinksProvider);
    final value = catalog.value;
    if (value == null) {
      return const WgSkeletonList(rows: 5, label: 'Loading hosts');
    }
    final registry = ref.read(commandRegistryProvider);
    ref.watch(settingsProvider.select((s) => s.hostOpenModes));
    Widget row(Host host) {
      final state = links[host.id]?.state ?? LinkState.idle;
      final mode = registry.lastOpenMode(host.id);
      List<WgMenuEntry> entries() => [
        ...registry.openHostEntries(host.id),
        WgMenuEntry(
          label: 'Open beside current pane',
          icon: WgIcons.splitHorizontal,
          onSelected: () =>
              registry.openHost(host.id, placement: PanePlacement.splitRight),
        ),
        const WgMenuEntry.divider(),
        WgMenuEntry(
          label: 'Edit host',
          icon: WgIcons.edit,
          onSelected: () =>
              GoRouter.of(context).go(Routes.hosts, extra: host.id),
        ),
        if (links[host.id]?.isUsable ?? false)
          WgMenuEntry(
            label: 'Disconnect',
            icon: WgIcons.close,
            onSelected: () =>
                unawaited(ref.read(connectionPoolProvider).disconnect(host.id)),
          ),
      ];
      return draggableHost(
        context,
        host,
        WgListRow(
          title: host.label,
          dense: true,
          leading: WgStatusDot(state: state.dot, subject: host.label),
          semanticLabel:
              '${host.label}, ${state.dot.label.toLowerCase()}. Open ${mode.label.toLowerCase()}',
          onPressed: () => registry.openHost(host.id),
          revealTrailing: true,
          trailing: WgMenuButton(
            icon: WgIcons.more,
            label: 'Open ${host.label} as',
            compact: true,
            entries: entries,
          ),
          onSecondaryTapDown: (details) => unawaited(
            showWgMenu(
              context,
              position: details.globalPosition,
              entries: entries(),
            ),
          ),
        ),
      );
    }

    final groups = value.groups;
    final ungroupedCollapsed = isGroupCollapsed(ref, ungroupedKey);
    final items = <WidgetBuilder>[
      (_) => WgSectionLabel(
        'Hosts',
        trailing: WgIconButton(
          icon: WgIcons.plus,
          label: 'Add host',
          compact: true,
          onPressed: () => GoRouter.of(context).go(Routes.hosts, extra: 'new'),
        ),
      ),
      if (value.hosts.isEmpty)
        (context) => Padding(
          padding: EdgeInsets.symmetric(horizontal: context.space.sm),
          child: Text(
            'No hosts yet',
            style: context.type.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ),
      if (groups.isNotEmpty && value.ungrouped.isNotEmpty)
        (_) => HostGroupHeader(
          groupKey: ungroupedKey,
          name: 'Ungrouped',
          count: value.ungrouped.length,
          renamable: false,
          dense: true,
          first: true,
        ),
      if (!ungroupedCollapsed || groups.isEmpty)
        for (final host in value.ungrouped) (_) => row(host),
      for (final group in groups) ...[
        (_) => HostGroupHeader(
          groupKey: group.id,
          groupId: group.id,
          name: group.name,
          count: value.inGroup(group.id).length,
          dense: true,
          first: value.ungrouped.isEmpty && identical(group, groups.first),
          trailing: value.inGroup(group.id).isEmpty
              ? null
              : WgIconButton(
                  icon: WgIcons.grid,
                  label: 'Open ${group.name} in a grid',
                  compact: true,
                  onPressed: () => registry.openHostsInGrid([
                    for (final host in value.inGroup(group.id)) host.id,
                  ], title: group.name),
                ),
        ),
        if (!isGroupCollapsed(ref, group.id))
          for (final host in value.inGroup(group.id)) (_) => row(host),
      ],
    ];
    return ListView.builder(
      padding: EdgeInsets.only(bottom: context.space.sm),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index](context),
    );
  }
}
