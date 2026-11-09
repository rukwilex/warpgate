import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/application/path_bar_controller.dart';
import 'package:warpgate/features/sftp/application/view_mode.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate/features/sftp/presentation/path_bar.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FileBrowserToolbar extends StatelessWidget {
  const new({
    required this.label,
    required this.dot,
    required this.attached,
    required this.following,
    required this.onFollow,
    required this.onGoToTerminal,
    required this.onInstallHook,
    required this.path,
    required this.endpoint,
    required this.pathBar,
    required this.favorite,
    required this.onFavorite,
    required this.onQuickJump,
    required this.onPickEndpoint,
    required this.onNavigate,
    required this.onUp,
    required this.onRefresh,
    required this.onNewFolder,
    required this.onUpload,
    required this.showHidden,
    required this.onToggleHidden,
    required this.showTree,
    required this.onToggleTree,
    required this.view,
    required this.onView,
    required this.filtering,
    required this.onToggleFilter,
    required this.onOpenTerminal,
    required this.onCopyPath,
    super.key,
  });

  final String label;
  final WgDotState dot;
  final bool attached;
  final bool following;
  final VoidCallback? onFollow;
  final VoidCallback? onGoToTerminal;
  final VoidCallback? onInstallHook;
  final String? path;
  final FileEndpoint? endpoint;
  final PathBarController pathBar;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback onQuickJump;
  final VoidCallback onPickEndpoint;
  final ValueChanged<String> onNavigate;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onNewFolder;
  final VoidCallback? onUpload;
  final bool showHidden;
  final VoidCallback onToggleHidden;
  final bool showTree;
  final VoidCallback onToggleTree;
  final ViewMode view;
  final ValueChanged<ViewMode> onView;
  final bool filtering;
  final VoidCallback onToggleFilter;
  final VoidCallback? onOpenTerminal;
  final VoidCallback? onCopyPath;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.maxWidth),
  );

  Widget _build(BuildContext context, double width) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final keyName = PlatformInfo.isApple ? 'Cmd' : 'Ctrl';
    final button = sizes.rowCompact - space.sm + space.hair;
    final roomy =
        width - space.xs * 2 >=
        sizes.columnName + button * FileBrowserConstants.toolbarButtonSlots;
    final leading = attached
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WgIconButton(
                icon: following ? WgIcons.follow : WgIcons.followOff,
                label: following
                    ? 'Stop following the terminal'
                    : 'Follow the terminal',
                compact: true,
                selected: following,
                onPressed: onFollow,
              ),
              if (onGoToTerminal != null) ...[
                SizedBox(width: space.hair),
                if (roomy)
                  Flexible(
                    child: WgButton.ghost(
                      label: 'Go to terminal folder',
                      icon: WgIcons.goTo,
                      onPressed: onGoToTerminal,
                    ),
                  )
                else
                  WgIconButton(
                    icon: WgIcons.goTo,
                    label: 'Go to terminal folder',
                    compact: true,
                    onPressed: onGoToTerminal,
                  ),
              ],
            ],
          )
        : WgPressable(
            semanticLabel: 'Location: $label. Change',
            onPressed: onPickEndpoint,
            borderRadius: context.radii.smAll,
            builder: (context, state) => Container(
              height: sizes.rowCompact - space.xs,
              padding: EdgeInsets.symmetric(horizontal: space.sm),
              decoration: BoxDecoration(
                color: state.highlighted ? colors.raised : colors.transparent,
                borderRadius: context.radii.smAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WgStatusDot(state: dot, subject: label),
                  if (roomy) ...[
                    SizedBox(width: space.sm),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.label,
                      ),
                    ),
                  ],
                  SizedBox(width: space.xs),
                  Icon(
                    WgIcons.chevronDown,
                    size: sizes.icon,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
          );
    final primary = SingleActivator(
      LogicalKeyboardKey.arrowUp,
      meta: PlatformInfo.isApple,
      control: !PlatformInfo.isApple,
    );
    final actions = <Widget>[
      WgIconButton(
        icon: WgIcons.arrowUp,
        label: 'Up one folder',
        compact: true,
        shortcut: primary,
        onPressed: onUp,
      ),
      WgIconButton(
        icon: WgIcons.refresh,
        label: 'Refresh',
        compact: true,
        onPressed: onRefresh,
      ),
      if (roomy) ...[
        WgIconButton(
          icon: WgIcons.search,
          label: 'Filter',
          compact: true,
          selected: filtering,
          onPressed: onToggleFilter,
        ),
        WgIconButton(
          icon: showHidden ? WgIcons.eye : WgIcons.hidden,
          label: showHidden ? 'Hide hidden files' : 'Show hidden files',
          compact: true,
          selected: showHidden,
          onPressed: onToggleHidden,
        ),
        WgIconButton(
          icon: favorite ? WgIcons.star : WgIcons.starOff,
          label: favorite ? 'Remove from favorites' : 'Add to favorites',
          compact: true,
          selected: favorite,
          onPressed: onFavorite,
        ),
        WgIconButton(
          icon: WgIcons.folderTree,
          label: showTree ? 'Hide folder tree' : 'Show folder tree',
          compact: true,
          selected: showTree,
          onPressed: onToggleTree,
        ),
      ],
      WgMenuButton(
        icon: WgIcons.more,
        label: 'More file actions',
        compact: true,
        entries: () => [
          if (!roomy) ...[
            WgMenuEntry(
              label: filtering ? 'Close filter' : 'Filter',
              icon: WgIcons.search,
              onSelected: onToggleFilter,
            ),
            WgMenuEntry(
              label: showHidden ? 'Hide hidden files' : 'Show hidden files',
              icon: showHidden ? WgIcons.eye : WgIcons.hidden,
              onSelected: onToggleHidden,
            ),
            WgMenuEntry(
              label: favorite ? 'Remove from favorites' : 'Add to favorites',
              icon: WgIcons.star,
              enabled: onFavorite != null,
              onSelected: () => onFavorite?.call(),
            ),
            WgMenuEntry(
              label: showTree ? 'Hide folder tree' : 'Show folder tree',
              icon: WgIcons.folderTree,
              onSelected: onToggleTree,
            ),
            const WgMenuEntry.divider(),
          ],
          WgMenuEntry(
            label: 'Jump to folder…',
            icon: WgIcons.goTo,
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyP,
              meta: PlatformInfo.isApple,
              control: !PlatformInfo.isApple,
            ),
            onSelected: onQuickJump,
          ),
          WgMenuEntry(
            label: 'Type a path…',
            icon: WgIcons.textCursor,
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyL,
              meta: PlatformInfo.isApple,
              control: !PlatformInfo.isApple,
            ),
            onSelected: pathBar.edit,
          ),
          WgMenuEntry(
            label: view == ViewMode.list ? 'Show as grid' : 'Show as list',
            icon: view == ViewMode.list ? WgIcons.grid : WgIcons.list,
            onSelected: () =>
                onView(view == ViewMode.list ? ViewMode.grid : ViewMode.list),
          ),
          const WgMenuEntry.divider(),
          WgMenuEntry(
            label: 'New folder',
            icon: WgIcons.folderPlus,
            onSelected: onNewFolder,
          ),
          if (onUpload != null)
            WgMenuEntry(
              label: 'Upload files…',
              icon: WgIcons.upload,
              onSelected: onUpload,
            ),
          WgMenuEntry(
            label: 'Copy path',
            icon: WgIcons.copy,
            enabled: onCopyPath != null,
            onSelected: () => onCopyPath?.call(),
          ),
          if (onOpenTerminal != null)
            WgMenuEntry(
              label: attached
                  ? 'Change the terminal to this folder'
                  : 'Open terminal here',
              icon: WgIcons.terminal,
              onSelected: onOpenTerminal,
            ),
          if (onInstallHook != null) ...[
            const WgMenuEntry.divider(),
            WgMenuEntry(
              label: 'Set up folder tracking on this host…',
              icon: WgIcons.follow,
              onSelected: onInstallHook,
            ),
          ],
        ],
      ),
    ];
    final pathBarWidget = Semantics(
      hint: 'Click to type a path. $keyName+L also works',
      child: PathBar(
        endpoint: endpoint,
        path: path,
        onNavigate: onNavigate,
        controller: pathBar,
      ),
    );
    final actionRow = [
      for (final (index, action) in actions.indexed) ...[
        if (index > 0) SizedBox(width: space.hair),
        action,
      ],
    ];
    final inline = width >= sizes.dialogWide;
    return Container(
      decoration: BoxDecoration(
        color: colors.canvasDeep,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      padding: EdgeInsets.all(space.xs),
      child: inline
          ? Row(
              children: [
                leading,
                SizedBox(width: space.sm),
                Expanded(child: pathBarWidget),
                SizedBox(width: space.sm),
                ...actionRow,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: leading,
                      ),
                    ),
                    SizedBox(width: space.xs),
                    ...actionRow,
                  ],
                ),
                SizedBox(height: space.xs),
                pathBarWidget,
              ],
            ),
    );
  }
}
