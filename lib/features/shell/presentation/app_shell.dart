import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/data/port_forwarder.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/hosts/presentation/host_groups.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/palette/presentation/palette_overlay.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/title_bar.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/transfers/domain/transfer_job.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

enum ShellLayout { phone, tablet, desktop }

ShellLayout shellLayoutOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < WgBreakpoints.medium) return ShellLayout.phone;
  if (width < WgBreakpoints.expanded) return ShellLayout.tablet;
  return ShellLayout.desktop;
}

@immutable
class _Destination {
  const new(this.route, this.label, this.icon, {this.commandId});

  final String route;
  final String label;
  final IconData icon;
  final String? commandId;
}

const _destinations = [
  _Destination(
    Routes.workbench,
    'Sessions',
    WgIcons.terminal,
    commandId: 'nav.workbench',
  ),
  _Destination(Routes.hosts, 'Hosts', WgIcons.server, commandId: 'nav.hosts'),
  _Destination(
    Routes.transfers,
    'Transfers',
    WgIcons.transfer,
    commandId: 'transfers.open',
  ),
  _Destination(
    Routes.multiExec,
    'Run on many',
    WgIcons.multiExec,
    commandId: 'multiExec.open',
  ),
  _Destination(
    Routes.snippets,
    'Snippets',
    WgIcons.snippet,
    commandId: 'nav.snippets',
  ),
  _Destination(Routes.keys, 'Keys', WgIcons.key, commandId: 'nav.keys'),
  _Destination(
    Routes.forwards,
    'Port forwards',
    WgIcons.forward,
    commandId: 'nav.forwards',
  ),
  _Destination(
    Routes.settings,
    'Settings',
    WgIcons.settings,
    commandId: 'settings.open',
  ),
];

const _phoneDestinations = [
  _Destination(Routes.workbench, 'Sessions', WgIcons.terminal),
  _Destination(Routes.hosts, 'Hosts', WgIcons.server),
  _Destination(Routes.transfers, 'Transfers', WgIcons.transfer),
  _Destination(Routes.multiExec, 'Many', WgIcons.multiExec),
  _Destination(Routes.settings, 'Settings', WgIcons.settings),
];

class AppShell extends ConsumerWidget {
  const new({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = shellLayoutOf(context);
    final collapsed = ref.watch(
      settingsProvider.select((s) => s.sidebarCollapsed),
    );
    final colors = context.colors;
    final content = PaletteOverlay(child: child);
    if (layout == ShellLayout.phone) {
      final index = _phoneDestinations
          .indexWhere((d) => d.route == _section(location))
          .clamp(0, _phoneDestinations.length - 1);
      return Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: content),
              const _PhoneStatus(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          backgroundColor: colors.canvasDeep,
          indicatorColor: colors.pressed,
          surfaceTintColor: colors.transparent,
          height: context.sizes.touchTarget + context.space.lg,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) =>
              GoRouter.of(context).go(_phoneDestinations[value].route),
          destinations: [
            for (final destination in _phoneDestinations)
              NavigationDestination(
                icon: Icon(
                  destination.icon,
                  size: context.sizes.icon,
                  color: colors.textSecondary,
                ),
                selectedIcon: Icon(
                  destination.icon,
                  size: context.sizes.icon,
                  color: colors.textPrimary,
                ),
                label: destination.label,
              ),
          ],
        ),
      );
    }
    final rail = layout == ShellLayout.tablet || collapsed;
    final titleBar = ref.watch(windowChromeProvider).custom;
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Sidebar(location: location, rail: rail, paletteButton: !titleBar),
        const WgHairline(vertical: true),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (titleBar) const WgHairline(),
              Expanded(child: content),
              const StatusBar(),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: colors.canvas,
      body: titleBar
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitleBar(onWorkbench: location == Routes.workbench),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }

  static String _section(String location) {
    if (location == Routes.workbench) return Routes.workbench;
    for (final destination in _destinations) {
      if (destination.route != Routes.workbench &&
          location.startsWith(destination.route)) {
        return destination.route;
      }
    }
    return Routes.workbench;
  }
}

class _Sidebar extends ConsumerWidget {
  const new({
    required this.location,
    required this.rail,
    required this.paletteButton,
  });

  final String location;
  final bool rail;
  final bool paletteButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final keys = ref.watch(shortcutMapProvider);
    final section = AppShell._section(location);
    final registry = ref.read(commandRegistryProvider);
    final nav = [
      for (final destination in _destinations)
        if (rail)
          Padding(
            padding: EdgeInsets.symmetric(vertical: space.hair),
            child: WgIconButton(
              icon: destination.icon,
              label: destination.label,
              selected: destination.route == section,
              shortcut: destination.commandId == null
                  ? null
                  : keys[destination.commandId],
              onPressed: () => GoRouter.of(context).go(destination.route),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(bottom: space.hair),
            child: WgListRow(
              title: destination.label,
              dense: true,
              leading: Icon(destination.icon),
              selected: destination.route == section,
              onPressed: () => GoRouter.of(context).go(destination.route),
            ),
          ),
    ];
    return Semantics(
      container: true,
      label: 'Sidebar',
      child: Container(
        width: rail ? sizes.rail : sizes.sidebar,
        color: colors.canvasDeep,
        padding: EdgeInsets.symmetric(
          horizontal: rail ? space.xs : space.sm,
          vertical: space.sm,
        ),
        child: Column(
          crossAxisAlignment: rail
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: sizes.rowCompact,
              child: Row(
                mainAxisAlignment: rail
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!rail) ...[
                    SizedBox(width: space.sm),
                    const WgLogoMark(),
                    SizedBox(width: space.sm),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Warpgate',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.title,
                        ),
                      ),
                    ),
                    if (paletteButton)
                      WgIconButton(
                        icon: WgIcons.search,
                        label: 'Command palette',
                        compact: true,
                        shortcut: keys['palette.open'],
                        onPressed: () => registry.run('palette.open'),
                      ),
                  ],
                  WgIconButton(
                    icon: WgIcons.sidebar,
                    label: rail ? 'Expand sidebar' : 'Collapse sidebar',
                    compact: true,
                    shortcut: keys['sidebar.toggle'],
                    onPressed: shellLayoutOf(context) == ShellLayout.desktop
                        ? () => registry.run('sidebar.toggle')
                        : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: space.md),
            ...nav,
            if (!rail) const Expanded(child: _HostList()) else const Spacer(),
            if (rail && paletteButton)
              WgIconButton(
                icon: WgIcons.search,
                label: 'Command palette',
                shortcut: keys['palette.open'],
                onPressed: () => registry.run('palette.open'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HostList extends ConsumerWidget {
  const new();

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
    return ListView(
      padding: EdgeInsets.only(bottom: context.space.sm),
      children: [
        WgSectionLabel(
          'Hosts',
          trailing: WgIconButton(
            icon: WgIcons.plus,
            label: 'Add host',
            compact: true,
            onPressed: () =>
                GoRouter.of(context).go(Routes.hosts, extra: 'new'),
          ),
        ),
        if (value.hosts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.space.sm),
            child: Text(
              'No hosts yet',
              style: context.type.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
        if (groups.isNotEmpty && value.ungrouped.isNotEmpty)
          HostGroupHeader(
            groupKey: ungroupedKey,
            name: 'Ungrouped',
            count: value.ungrouped.length,
            renamable: false,
            dense: true,
          ),
        if (!ungroupedCollapsed || groups.isEmpty)
          for (final host in value.ungrouped) row(host),
        for (final group in groups) ...[
          HostGroupHeader(
            groupKey: group.id,
            groupId: group.id,
            name: group.name,
            count: value.inGroup(group.id).length,
            dense: true,
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
            for (final host in value.inGroup(group.id)) row(host),
        ],
      ],
    );
  }
}

class StatusBar extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final links = ref.watch(hostLinksProvider);
    final bench = ref.watch(workbenchProvider);
    final mcp = ref.watch(mcpServerProvider);
    final forwards = ref.watch(activeForwardsProvider);
    final connected = links.values.where((link) => link.isUsable).length;
    final reconnecting = links.values
        .where((link) => link.state == LinkState.connecting)
        .length;
    final dropped = links.values
        .where((link) => link.state == LinkState.dropped)
        .length;
    final broadcast = bench.broadcastPaneIds.length;
    final activeForwards = forwards
        .where((forward) => forward.state == ForwardState.active)
        .length;
    final meta = context.type.monoSmall.copyWith(color: colors.textMuted);
    return Container(
      height: context.sizes.statusBar,
      padding: EdgeInsets.symmetric(horizontal: space.sm),
      decoration: BoxDecoration(
        color: colors.canvasDeep,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          _StatusItem(
            label:
                '$connected connected${reconnecting > 0 ? ', $reconnecting connecting' : ''}${dropped > 0 ? ', $dropped dropped' : ''}',
            onPressed: () => GoRouter.of(context).go(Routes.hosts),
            child: Row(
              children: [
                WgStatusDot(
                  state: dropped > 0
                      ? WgDotState.dropped
                      : connected > 0
                      ? WgDotState.connected
                      : WgDotState.idle,
                ),
                SizedBox(width: space.sm),
                Text(
                  '$connected connected${reconnecting > 0 ? ' · $reconnecting connecting' : ''}${dropped > 0 ? ' · $dropped dropped' : ''}',
                  style: meta,
                ),
              ],
            ),
          ),
          if (broadcast > 1) ...[
            SizedBox(width: space.md),
            _StatusItem(
              label: 'Broadcasting to $broadcast panes. Stop',
              onPressed: () =>
                  ref.read(workbenchProvider.notifier).setBroadcast(const {}),
              child: Row(
                children: [
                  Icon(
                    WgIcons.broadcast,
                    size: context.sizes.icon,
                    color: colors.accentInk,
                  ),
                  SizedBox(width: space.xs),
                  Text(
                    'Broadcast · $broadcast panes',
                    style: meta.copyWith(color: colors.accentInk),
                  ),
                ],
              ),
            ),
          ],
          if (activeForwards > 0) ...[
            SizedBox(width: space.md),
            _StatusItem(
              label: '$activeForwards port forwards active',
              onPressed: () => GoRouter.of(context).go(Routes.forwards),
              child: Row(
                children: [
                  Icon(
                    WgIcons.forward,
                    size: context.sizes.icon,
                    color: colors.textMuted,
                  ),
                  SizedBox(width: space.xs),
                  Text('$activeForwards forwards', style: meta),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (mcp.running) ...[
            _StatusItem(
              label:
                  'Claude Code server running on port ${mcp.port}. Open activity',
              onPressed: () => GoRouter.of(context).go(Routes.mcpActivity),
              child: Row(
                children: [
                  Icon(
                    WgIcons.bot,
                    size: context.sizes.icon,
                    color: colors.textMuted,
                  ),
                  SizedBox(width: space.xs),
                  Text('MCP :${mcp.port}', style: meta),
                ],
              ),
            ),
            SizedBox(width: space.md),
          ],
          const TransferIndicator(),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => WgPressable(
    semanticLabel: label,
    onPressed: onPressed,
    borderRadius: context.radii.xsAll,
    builder: (context, state) => Container(
      padding: EdgeInsets.symmetric(horizontal: context.space.xs),
      decoration: BoxDecoration(
        color: state.highlighted
            ? context.colors.raised
            : context.colors.transparent,
        borderRadius: context.radii.xsAll,
      ),
      child: child,
    ),
  );
}

class TransferIndicator extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(transferQueueProvider);
    final running = jobs
        .where((job) => job.status == TransferStatus.running)
        .toList();
    final queued = jobs
        .where((job) => job.status == TransferStatus.queued)
        .length;
    final failed = jobs
        .where((job) => job.status == TransferStatus.failed)
        .length;
    final colors = context.colors;
    final meta = context.type.monoSmall.copyWith(color: colors.textMuted);
    if (running.isEmpty && queued == 0 && failed == 0) {
      return _StatusItem(
        label: 'Transfers, none active',
        onPressed: () => GoRouter.of(context).go(Routes.transfers),
        child: Row(
          children: [
            Icon(
              WgIcons.transfer,
              size: context.sizes.icon,
              color: colors.textMuted,
            ),
            SizedBox(width: context.space.xs),
            Text('No transfers', style: meta),
          ],
        ),
      );
    }
    final total = running.fold<int>(0, (sum, job) => sum + job.totalBytes);
    final done = running.fold<int>(0, (sum, job) => sum + job.doneBytes);
    final speed = running.fold<double>(
      0,
      (sum, job) => sum + job.bytesPerSecond,
    );
    final fraction = total == 0 ? null : done / total;
    final text = [
      if (running.isNotEmpty) '${running.length} running',
      if (queued > 0) '$queued queued',
      if (speed > 0) Format.speed(speed),
    ].join(' · ');
    final failedText = failed > 0 ? '$failed failed' : '';
    return _StatusItem(
      label:
          'Transfers: ${[text, failedText].where((part) => part.isNotEmpty).join(', ')}. Open queue',
      onPressed: () => GoRouter.of(context).go(Routes.transfers),
      child: Row(
        children: [
          Icon(
            WgIcons.transfer,
            size: context.sizes.icon,
            color: colors.textSecondary,
          ),
          SizedBox(width: context.space.xs),
          if (text.isNotEmpty)
            Text(text, style: meta.copyWith(color: colors.textSecondary)),
          if (text.isNotEmpty && failedText.isNotEmpty)
            Text(' · ', style: meta),
          if (failedText.isNotEmpty)
            Text(failedText, style: meta.copyWith(color: colors.negative)),
          if (running.isNotEmpty) ...[
            SizedBox(width: context.space.sm),
            SizedBox(
              width: context.space.huge,
              child: WgProgressBar(value: fraction, label: 'Transfer progress'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneStatus extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(transferQueueProvider);
    final active = jobs.any((job) => job.status.isActive);
    final connected = ref
        .watch(hostLinksProvider)
        .values
        .any((link) => link.isUsable);
    if (!active && !connected) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.md,
        vertical: context.space.xs,
      ),
      color: context.colors.canvasDeep,
      child: Row(
        children: [
          Icon(
            WgIcons.info,
            size: context.sizes.icon,
            color: context.colors.textMuted,
          ),
          SizedBox(width: context.space.sm),
          Expanded(
            child: Text(
              PlatformInfo.isMobile
                  ? 'Sessions stay open while Warpgate is on screen. The system may pause them in the background.'
                  : 'Sessions are active',
              style: context.type.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
          if (active) const TransferIndicator(),
        ],
      ),
    );
  }
}
