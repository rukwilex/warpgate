import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

class PaneFrame extends ConsumerStatefulWidget {
  const new({
    required this.pane,
    required this.title,
    required this.dot,
    required this.child,
    super.key,
    this.subtitle,
    this.menu = const [],
    this.actions = const [],
    this.compact = false,
  });

  final Pane pane;
  final String title;
  final String? subtitle;
  final WgDotState dot;
  final Widget child;
  final List<WgMenuEntry> menu;
  final List<Widget> actions;
  final bool compact;

  @override
  ConsumerState<PaneFrame> createState() => _PaneFrameState();
}

class _PaneFrameState extends ConsumerState<PaneFrame> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final bench = ref.watch(workbenchProvider);
    final location = bench.locate(widget.pane.id);
    final tab = location?.tab;
    final focused = tab?.focusedPaneId == widget.pane.id;
    final multiple = (tab?.panes.length ?? 0) > 1;
    final maximized = tab?.maximizedPaneId == widget.pane.id;
    final broadcasting =
        bench.broadcastPaneIds.contains(widget.pane.id) &&
        bench.broadcastPaneIds.length > 1;
    final controller = ref.read(workbenchProvider.notifier);
    final keys = ref.watch(shortcutMapProvider);
    final showActions = _hovered || focused || PlatformInfo.isMobile;
    final borderColor = broadcasting
        ? colors.accent
        : focused && multiple
        ? colors.hairlineStrong
        : colors.hairline;
    return Listener(
      onPointerDown: (_) => controller.focusPane(widget.pane.id),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          decoration: BoxDecoration(
            color: colors.canvas,
            border: Border.all(
              color: borderColor,
              width: broadcasting ? sizes.markerBar : sizes.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.compact)
                Semantics(
                  container: true,
                  label:
                      '${widget.title} pane${focused ? ', focused' : ''}${broadcasting ? ', receiving broadcast' : ''}',
                  child: Container(
                    height: sizes.rowCompact,
                    padding: EdgeInsets.symmetric(horizontal: space.sm),
                    decoration: BoxDecoration(
                      color: focused ? colors.surface : colors.canvasDeep,
                      border: Border(
                        top: BorderSide(
                          color: focused && multiple
                              ? colors.accent
                              : colors.transparent,
                          width: sizes.markerBar,
                        ),
                        bottom: BorderSide(color: colors.hairline),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          key: const ValueKey('pane-title'),
                          child: Row(
                            children: [
                              WgStatusDot(
                                state: widget.dot,
                                subject: widget.title,
                              ),
                              SizedBox(width: space.sm),
                              Flexible(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.type.label.copyWith(
                                    color: focused
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                SizedBox(width: space.sm),
                                Flexible(
                                  child: Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.type.monoSmall.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                              if (broadcasting) ...[
                                SizedBox(width: space.sm),
                                WgTag('Broadcast', tone: colors.accentInk),
                              ],
                              if (widget.pane.origin ==
                                  PaneOrigin.claudeCode) ...[
                                SizedBox(width: space.sm),
                                const WgTag('Claude Code'),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: space.sm),
                        _HeaderActions(
                          visible: showActions,
                          children: [
                            ...widget.actions,
                            WgIconButton(
                              icon: WgIcons.splitHorizontal,
                              label: 'Split right',
                              compact: true,
                              shortcut: keys['pane.splitRight'],
                              onPressed: () => ref
                                  .read(commandRegistryProvider)
                                  .run('pane.splitRight'),
                            ),
                            WgIconButton(
                              icon: WgIcons.splitVertical,
                              label: 'Split down',
                              compact: true,
                              shortcut: keys['pane.splitDown'],
                              onPressed: () => ref
                                  .read(commandRegistryProvider)
                                  .run('pane.splitDown'),
                            ),
                            if (multiple)
                              WgIconButton(
                                icon: maximized
                                    ? WgIcons.minimize
                                    : WgIcons.maximize,
                                label: maximized
                                    ? 'Restore pane'
                                    : 'Maximize pane',
                                compact: true,
                                shortcut: keys['pane.maximize'],
                                onPressed: () =>
                                    controller.toggleMaximize(widget.pane.id),
                              ),
                            WgMenuButton(
                              icon: WgIcons.more,
                              label: 'Pane actions',
                              compact: true,
                              entries: () => [
                                ...widget.menu,
                                if (widget.menu.isNotEmpty)
                                  const WgMenuEntry.divider(),
                                ..._layoutEntries(context, multiple: multiple),
                              ],
                            ),
                            WgIconButton(
                              icon: WgIcons.close,
                              label: 'Close pane',
                              compact: true,
                              shortcut: keys['pane.close'],
                              onPressed: () =>
                                  controller.closePane(widget.pane.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }

  List<WgMenuEntry> _layoutEntries(
    BuildContext context, {
    required bool multiple,
  }) {
    final controller = ref.read(workbenchProvider.notifier);
    final bench = ref.read(workbenchProvider);
    final keys = ref.read(shortcutMapProvider);
    final id = widget.pane.id;
    final isTerminal =
        widget.pane.content is SshTerminalContent ||
        widget.pane.content is LocalTerminalContent;
    return [
      if (isTerminal)
        WgMenuEntry(
          label: bench.broadcastPaneIds.contains(id)
              ? 'Stop broadcasting to this pane'
              : 'Add to broadcast',
          icon: WgIcons.broadcast,
          onSelected: () => controller.toggleBroadcast(id),
        ),
      if (multiple) ...[
        WgMenuEntry(
          label: 'Swap with pane on the right',
          icon: WgIcons.swap,
          onSelected: () {
            controller
              ..focusPane(id)
              ..swapWithNeighbor(PaneDirection.right);
          },
        ),
        WgMenuEntry(
          label: 'Move to new tab',
          icon: WgIcons.arrowRight,
          onSelected: () => controller.movePaneToTab(id),
        ),
      ],
      for (final workspace in bench.workspaces)
        if (workspace.id != bench.locate(id)?.workspace.id)
          WgMenuEntry(
            label: 'Move to ${workspace.name}',
            icon: WgIcons.workspace,
            onSelected: () => controller.movePaneToWorkspace(id, workspace.id),
          ),
      WgMenuEntry(
        label: 'Close pane',
        icon: WgIcons.close,
        shortcut: keys['pane.close'],
        destructive: true,
        onSelected: () => controller.closePane(id),
      ),
    ];
  }
}

class _HeaderActions extends StatelessWidget {
  const new({required this.visible, required this.children});

  final bool visible;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = context.space.hair;
    return AnimatedOpacity(
      key: const ValueKey('pane-actions'),
      opacity: visible ? 1 : 0,
      duration: context.motion.fast,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) SizedBox(width: gap),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
