import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/sftp/presentation/file_drop.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/presentation/widgets/workbench_tab_scroller.dart';
import 'package:warpgate/features/workspace/presentation/widgets/workspace_switcher.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate/features/workspace/utils/tab_sizing.dart';
import 'package:warpgate/features/workspace/utils/worst_link_state.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';
import 'package:warpgate_core/features/workspace/domain/workspace.dart';

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
        WorkspaceSwitcher(workspace: workspace),
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
              return WorkbenchTabScroller(
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
