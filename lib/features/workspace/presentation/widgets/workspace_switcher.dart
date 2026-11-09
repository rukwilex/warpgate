import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate/features/workspace/presentation/workspace_constants.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/workspace/domain/workspace.dart';

class WorkspaceSwitcher extends ConsumerWidget {
  const new({required this.workspace, super.key});

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
                    shortcut: index < WorkspaceConstants.numberedShortcuts
                        ? keys['workspace.${index + 1}']
                        : null,
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
