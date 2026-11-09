import 'package:flutter/widgets.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

List<WgMenuEntry> terminalContextMenuEntries({
  required String paneId,
  required Map<String, SingleActivator> keys,
  required CommandRegistry registry,
  required WorkbenchController bench,
  required bool hasSelection,
  required bool filesOpen,
  required bool isSsh,
  required VoidCallback onCopy,
  required VoidCallback onPaste,
  required VoidCallback onClearScrollback,
  required VoidCallback onShowInFiles,
  required VoidCallback onToggleFiles,
}) => [
  WgMenuEntry(
    label: 'Copy',
    icon: WgIcons.copy,
    enabled: hasSelection,
    onSelected: onCopy,
  ),
  WgMenuEntry(
    label: 'Paste',
    icon: WgIcons.paste,
    onSelected: onPaste,
  ),
  WgMenuEntry(
    label: 'Clear scrollback',
    icon: WgIcons.trash,
    onSelected: onClearScrollback,
  ),
  if (hasSelection)
    WgMenuEntry(
      label: 'Show in files',
      icon: WgIcons.folderOpen,
      onSelected: onShowInFiles,
    ),
  const WgMenuEntry.divider(),
  WgMenuEntry(
    label: filesOpen ? 'Hide files' : 'Show files',
    icon: WgIcons.filesPanel,
    shortcut: keys['sftp.here'],
    onSelected: onToggleFiles,
  ),
  if (isSsh)
    WgMenuEntry(
      label: 'Open files in a new pane',
      icon: WgIcons.folder,
      onSelected: () {
        bench.focusPane(paneId);
        registry.openSftpHere();
      },
    ),
  WgMenuEntry(
    label: 'Split right',
    icon: WgIcons.splitHorizontal,
    shortcut: keys['pane.splitRight'],
    onSelected: () => registry.run('pane.splitRight'),
  ),
  WgMenuEntry(
    label: 'Split down',
    icon: WgIcons.splitVertical,
    shortcut: keys['pane.splitDown'],
    onSelected: () => registry.run('pane.splitDown'),
  ),
  WgMenuEntry(
    label: 'Toggle broadcast',
    icon: WgIcons.broadcast,
    onSelected: () => bench.toggleBroadcast(paneId),
  ),
  const WgMenuEntry.divider(),
  WgMenuEntry(
    label: 'Close pane',
    icon: WgIcons.close,
    destructive: true,
    shortcut: keys['pane.close'],
    onSelected: () => bench.closePane(paneId),
  ),
];

List<WgMenuEntry> terminalPaneMenuEntries({
  required bool treeShown,
  required bool filesOpen,
  required bool isSsh,
  required VoidCallback onToggleTree,
  required VoidCallback onInstallHook,
}) => [
  WgMenuEntry(
    label: treeShown ? 'Hide folder tree' : 'Show folder tree',
    icon: WgIcons.folderTree,
    enabled: filesOpen,
    onSelected: onToggleTree,
  ),
  if (isSsh)
    WgMenuEntry(
      label: 'Set up folder tracking…',
      icon: WgIcons.follow,
      onSelected: onInstallHook,
    ),
];
