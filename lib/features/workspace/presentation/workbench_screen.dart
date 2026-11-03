import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/sftp/presentation/sftp_pane.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/terminal/presentation/log_tail_pane.dart';
import 'package:warpgate/features/terminal/presentation/terminal_pane.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/domain/workspace.dart';
import 'package:warpgate/features/workspace/presentation/layout_view.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

Widget buildPane(Pane pane, {bool compactChrome = false}) =>
    switch (pane.content) {
      SshTerminalContent() || LocalTerminalContent() => TerminalPane(
        pane: pane,
        compactChrome: compactChrome,
      ),
      SftpContent() => SftpPane(pane: pane, compactChrome: compactChrome),
      LogTailContent() => LogTailPane(pane: pane, compactChrome: compactChrome),
    };

LinkState worstState(Iterable<LinkState> states) {
  const order = [
    LinkState.dropped,
    LinkState.reconnecting,
    LinkState.connecting,
    LinkState.busy,
    LinkState.connected,
    LinkState.idle,
  ];
  final list = states.toList();
  if (list.isEmpty) return LinkState.idle;
  return order.firstWhere(list.contains, orElse: () => LinkState.idle);
}

class WorkbenchScreen extends ConsumerWidget {
  const new({super.key, this.phone = false});

  final bool phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bench = ref.watch(workbenchProvider);
    final workspace = bench.activeWorkspace;
    final tab = workspace?.activeTab;
    final tabsInTitleBar = ref.watch(windowChromeProvider).custom;
    if (phone) return const _PhoneWorkbench();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!tabsInTitleBar) const _TabStrip(),
        Expanded(
          child: tab == null || tab.isEmpty
              ? const _EmptyWorkbench()
              : LayoutView(
                  key: ValueKey(tab.id),
                  tab: tab,
                  paneBuilder: (context, paneId) =>
                      buildPane(tab.panes[paneId]!),
                ),
        ),
      ],
    );
  }
}

class _EmptyWorkbench extends ConsumerWidget {
  const new();

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

class _TabStrip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Container(
    height: context.sizes.tabBar,
    padding: EdgeInsets.symmetric(horizontal: context.space.sm),
    decoration: BoxDecoration(
      color: context.colors.canvasDeep,
      border: Border(bottom: BorderSide(color: context.colors.hairline)),
    ),
    child: const SessionTabs(),
  );
}

abstract final class TabSizing {
  static double width({
    required double available,
    required int count,
    required double min,
    required double max,
  }) {
    if (count <= 0) return max;
    return (available / count).floorToDouble().clamp(min, max);
  }
}

class _TabScroller extends StatefulWidget {
  const new({
    required this.activeIndex,
    required this.tabWidth,
    required this.builder,
  });

  final int activeIndex;
  final double tabWidth;
  final Widget Function(ScrollController scroll) builder;

  @override
  State<_TabScroller> createState() => _TabScrollerState();
}

class _TabScrollerState extends State<_TabScroller> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_TabScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex ||
        oldWidget.tabWidth != widget.tabWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    if (!mounted || !_scroll.hasClients || widget.activeIndex < 0) return;
    final position = _scroll.position;
    final start = widget.activeIndex * widget.tabWidth;
    final end = start + widget.tabWidth;
    final viewport = position.viewportDimension;
    var target = position.pixels;
    if (start < target) target = start;
    if (end > target + viewport) target = end - viewport;
    target = target.clamp(0, position.maxScrollExtent);
    if (target != position.pixels) _scroll.jumpTo(target);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_scroll);
}

class SessionTabs extends ConsumerWidget {
  const new({super.key, this.embedded = false, this.onWorkbench = true});

  final bool embedded;
  final bool onWorkbench;

  String _tabTitle(WidgetRef ref, WorkspaceTab tab) {
    if (tab.title != null) return tab.title!;
    final catalog = ref.watch(hostsProvider).value;
    final focused = tab.focusedPane ?? tab.panes.values.firstOrNull;
    final label = switch (focused?.content) {
      SshTerminalContent(:final hostId) =>
        catalog?.host(hostId)?.label ?? 'Removed host',
      LocalTerminalContent() => 'Local',
      SftpContent(:final left, :final right) when right != null =>
        '${left.isLocal ? 'This device' : catalog?.host(left.hostId)?.label} and ${right.isLocal ? 'This device' : catalog?.host(right.hostId)?.label}',
      SftpContent(:final left) =>
        'Files · ${left.isLocal ? 'This device' : catalog?.host(left.hostId)?.label}',
      LogTailContent(:final path) => 'tail ${path.split('/').last}',
      null => 'Empty',
    };
    return tab.panes.length > 1 ? '$label +${tab.panes.length - 1}' : label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bench = ref.watch(workbenchProvider);
    final workspace = bench.activeWorkspace;
    final sessions = ref.watch(terminalSessionsProvider);
    final links = ref.watch(hostLinksProvider);
    final keys = ref.watch(shortcutMapProvider);
    final controller = ref.read(workbenchProvider.notifier);
    final colors = context.colors;
    final space = context.space;
    if (workspace == null) return const SizedBox.shrink();
    LinkState paneState(Pane pane) {
      final session = sessions[pane.id];
      if (session != null) return session.status.value.state;
      final hostId = pane.content.hostId;
      if (hostId == null) return LinkState.connected;
      return links[hostId]?.state ?? LinkState.idle;
    }

    void select(String tabId) {
      controller.selectTab(tabId);
      if (!onWorkbench) GoRouter.of(context).go(Routes.workbench);
    }

    Widget tabStrip(
      double tabWidth,
      ScrollController scroll, {
      required bool fits,
    }) => ReorderableListView.builder(
      scrollController: scroll,
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      clipBehavior: fits ? Clip.none : Clip.hardEdge,
      physics: fits ? const NeverScrollableScrollPhysics() : null,
      itemExtent: tabWidth,
      itemCount: workspace.tabs.length,
      onReorderItem: (from, to) =>
          controller.moveTab(workspace.tabs[from].id, to),
      proxyDecorator: (child, _, _) =>
          Material(color: colors.transparent, child: child),
      itemBuilder: (context, index) {
        final tab = workspace.tabs[index];
        final selected = onWorkbench && tab.id == workspace.activeTab?.id;
        final state = worstState(tab.panes.values.map(paneState));
        final broadcasting =
            tab.panes.keys.any(bench.broadcastPaneIds.contains) &&
            bench.broadcastPaneIds.length > 1;
        final byClaude = tab.panes.values.any(
          (pane) => pane.origin == PaneOrigin.claudeCode,
        );
        final title = _tabTitle(ref, tab);
        return ReorderableDragStartListener(
          key: ValueKey(tab.id),
          index: index,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: space.hair),
            child: DragHoverSwitch(
              onSwitch: () => select(tab.id),
              child: Align(
                child: WgTabChip(
                  label: title,
                  selected: selected,
                  marker: broadcasting ? colors.accent : null,
                  leading: WgStatusDot(state: state.dot, subject: title),
                  trailing: byClaude
                      ? Tooltip(
                          message: 'Opened by Claude Code',
                          child: Icon(
                            WgIcons.bot,
                            size: context.sizes.icon,
                            color: colors.textMuted,
                            semanticLabel: 'Opened by Claude Code',
                          ),
                        )
                      : null,
                  onPressed: () => select(tab.id),
                  onClose: () => controller.closeTab(tab.id),
                  onSecondaryTapDown: (details) => unawaited(
                    showWgMenu(
                      context,
                      position: details.globalPosition,
                      entries: [
                        WgMenuEntry(
                          label: 'Rename tab',
                          icon: WgIcons.edit,
                          onSelected: () =>
                              unawaited(_renameTab(context, ref, tab, title)),
                        ),
                        WgMenuEntry(
                          label: 'Broadcast to this tab',
                          icon: WgIcons.broadcast,
                          onSelected: () {
                            select(tab.id);
                            controller.toggleBroadcastForTab();
                          },
                        ),
                        WgMenuEntry(
                          label: 'Close tab',
                          icon: WgIcons.close,
                          destructive: true,
                          onSelected: () => controller.closeTab(tab.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final plus = WgIconButton(
      key: const ValueKey('new-tab'),
      icon: WgIcons.plus,
      label: 'New terminal',
      compact: true,
      shortcut: keys['session.new'],
      onPressed: () =>
          unawaited(ref.read(commandRegistryProvider).newSession()),
    );
    final sizes = context.sizes;
    final activeIndex = workspace.tabs.indexWhere(
      (tab) => tab.id == workspace.activeTab?.id,
    );
    return Row(
      children: [
        _WorkspaceSwitcher(workspace: workspace),
        SizedBox(width: space.xs),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final plusWidth = sizes.rowCompact - space.sm + space.xs;
              final available = (constraints.maxWidth - plusWidth).clamp(
                0.0,
                double.infinity,
              );
              final count = workspace.tabs.length;
              final tabWidth = TabSizing.width(
                available: available,
                count: count,
                min: sizes.tabMin,
                max: sizes.tabMax,
              );
              final fits = tabWidth * count <= available;
              return _TabScroller(
                activeIndex: activeIndex,
                tabWidth: tabWidth,
                builder: (scroll) => Row(
                  children: [
                    SizedBox(
                      key: const ValueKey('tab-strip'),
                      width: fits ? tabWidth * count : available,
                      height: constraints.maxHeight,
                      child: tabStrip(tabWidth, scroll, fits: fits),
                    ),
                    SizedBox(width: space.xs),
                    plus,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _renameTab(
    BuildContext context,
    WidgetRef ref,
    WorkspaceTab tab,
    String current,
  ) async {
    final controller = TextEditingController(text: tab.title ?? current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => WgDialog(
        title: 'Rename tab',
        actions: [
          WgButton.ghost(
            label: 'Use automatic name',
            onPressed: () => Navigator.of(dialogContext).pop(''),
          ),
          WgButton.primary(
            label: 'Rename',
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
        child: WgTextField(
          controller: controller,
          label: 'Name',
          autofocus: true,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
      ),
    );
    controller.dispose();
    if (name != null) {
      ref.read(workbenchProvider.notifier).renameTab(tab.id, name);
    }
  }
}

class _WorkspaceSwitcher extends ConsumerWidget {
  const new({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bench = ref.watch(workbenchProvider);
    final keys = ref.watch(shortcutMapProvider);
    final registry = ref.read(commandRegistryProvider);
    final controller = ref.read(workbenchProvider.notifier);
    final colors = context.colors;
    return Builder(
      builder: (buttonContext) => WgPressable(
        semanticLabel: 'Workspace ${workspace.name}. Switch workspace',
        borderRadius: context.radii.smAll,
        onPressed: () {
          final box = buttonContext.findRenderObject()! as RenderBox;
          unawaited(
            showWgMenu(
              buttonContext,
              position: box.localToGlobal(Offset(0, box.size.height)),
              entries: [
                for (final (index, item) in bench.workspaces.indexed)
                  WgMenuEntry(
                    label: item.name,
                    icon: item.id == workspace.id ? WgIcons.check : null,
                    shortcut: index < 9 ? keys['workspace.${index + 1}'] : null,
                    onSelected: () => controller.switchWorkspace(item.id),
                  ),
                const WgMenuEntry.divider(),
                WgMenuEntry(
                  label: 'New workspace',
                  icon: WgIcons.plus,
                  onSelected: () => registry.run('workspace.new'),
                ),
                WgMenuEntry(
                  label: 'Rename workspace',
                  icon: WgIcons.edit,
                  onSelected: () => registry.run('workspace.rename'),
                ),
                WgMenuEntry(
                  label: 'Save layout as…',
                  icon: WgIcons.save,
                  shortcut: keys['layout.save'],
                  onSelected: () => registry.run('layout.save'),
                ),
                WgMenuEntry(
                  label: 'Open saved layout…',
                  icon: WgIcons.history,
                  onSelected: () => registry.run('layout.open'),
                ),
                if (bench.workspaces.length > 1)
                  WgMenuEntry(
                    label: 'Delete workspace',
                    icon: WgIcons.trash,
                    destructive: true,
                    onSelected: () => unawaited(_delete(context, ref)),
                  ),
              ],
            ),
          );
        },
        builder: (context, state) => Container(
          height: context.sizes.tabBar - context.space.sm,
          padding: EdgeInsets.symmetric(horizontal: context.space.sm),
          decoration: BoxDecoration(
            color: state.highlighted ? colors.raised : colors.transparent,
            borderRadius: context.radii.smAll,
          ),
          child: Row(
            children: [
              Icon(
                WgIcons.workspace,
                size: context.sizes.icon,
                color: colors.textMuted,
              ),
              SizedBox(width: context.space.sm),
              Text(
                workspace.name,
                style: context.type.label.copyWith(color: colors.textPrimary),
              ),
              SizedBox(width: context.space.xs),
              Icon(
                WgIcons.chevronDown,
                size: context.sizes.icon,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final panes = workspace.panes.length;
    final ok = await showWgConfirm(
      context,
      title: 'Delete ${workspace.name}?',
      message: panes == 0
          ? 'The workspace has no open tabs.'
          : 'Its ${Format.plural(panes, 'pane')} will close and their sessions will disconnect.',
      confirmLabel: 'Delete workspace',
      destructive: true,
    );
    if (ok) ref.read(workbenchProvider.notifier).deleteWorkspace(workspace.id);
  }
}

class _PhoneWorkbench extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_PhoneWorkbench> createState() => _PhoneWorkbenchState();
}

class _PhoneWorkbenchState extends ConsumerState<_PhoneWorkbench> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = ref.watch(workbenchProvider);
    final workspace = bench.activeWorkspace;
    final panes = [
      for (final tab in workspace?.tabs ?? const <WorkspaceTab>[])
        for (final id in tab.paneOrder) (tab: tab, pane: tab.panes[id]!),
    ];
    if (panes.isEmpty) return const _EmptyWorkbench();
    final focusedId = bench.activeTab?.focusedPaneId;
    final current = panes
        .indexWhere((item) => item.pane.id == focusedId)
        .clamp(0, panes.length - 1);
    if (_pages.hasClients && _pages.page?.round() != current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(current);
      });
    }
    return Column(
      children: [
        _PhoneSessionStrip(
          panes: [for (final item in panes) item.pane],
          current: current,
          onSelect: (index) {
            _pages.animateToPage(
              index,
              duration: context.motion.medium,
              curve: context.motion.curve,
            );
          },
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: panes.length,
            onPageChanged: (index) {
              final item = panes[index];
              ref.read(workbenchProvider.notifier)
                ..selectTab(item.tab.id)
                ..focusPane(item.pane.id);
            },
            itemBuilder: (context, index) => buildPane(panes[index].pane),
          ),
        ),
      ],
    );
  }
}

class _PhoneSessionStrip extends ConsumerWidget {
  const new({
    required this.panes,
    required this.current,
    required this.onSelect,
  });

  final List<Pane> panes;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(hostsProvider).value;
    final sessions = ref.watch(terminalSessionsProvider);
    final links = ref.watch(hostLinksProvider);
    return Container(
      height: context.sizes.touchTarget,
      decoration: BoxDecoration(
        color: context.colors.canvasDeep,
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.space.xs),
        itemCount: panes.length + 1,
        itemBuilder: (context, index) {
          if (index == panes.length) {
            return WgIconButton(
              icon: WgIcons.plus,
              label: 'New terminal',
              onPressed: () =>
                  unawaited(ref.read(commandRegistryProvider).newSession()),
            );
          }
          final pane = panes[index];
          final hostId = pane.content.hostId;
          final label = switch (pane.content) {
            SshTerminalContent() ||
            LogTailContent() => catalog?.host(hostId)?.label ?? 'Removed host',
            LocalTerminalContent() => 'Local',
            SftpContent() => 'Files',
          };
          final state =
              sessions[pane.id]?.status.value.state ??
              (hostId == null
                  ? LinkState.connected
                  : links[hostId]?.state ?? LinkState.idle);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.space.hair,
              vertical: context.space.xs,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: context.sizes.tabMin,
                maxWidth: context.sizes.tabMax,
              ),
              child: WgTabChip(
                label: label,
                selected: index == current,
                leading: WgStatusDot(state: state.dot, subject: label),
                onPressed: () => onSelect(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
