import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

class NativeMenus extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return child;
    final registry = ref.read(commandRegistryProvider);
    final keys = ref.watch(shortcutMapProvider);
    final workspaces = ref.watch(
      workbenchProvider.select(
        (state) => [for (final w in state.workspaces) w.name],
      ),
    );
    PlatformMenuItem item(String id, String label) => PlatformMenuItem(
      label: label,
      shortcut: keys[id],
      onSelected: () => registry.run(id),
    );
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Warpgate',
          menus: [
            PlatformMenuItemGroup(
              members: [
                if (PlatformProvidedMenuItem.hasMenu(
                  PlatformProvidedMenuItemType.about,
                ))
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.about,
                  ),
                item('settings.open', 'Settings…'),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItemGroup(
              members: [
                item('session.new', 'New Terminal…'),
                item('session.local', 'New Local Terminal'),
                item('sftp.new', 'Browse Files…'),
                item('sftp.dual', 'Two-Pane File Browser'),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                item('layout.save', 'Save Layout As…'),
                item('layout.open', 'Open Saved Layout…'),
              ],
            ),
            PlatformMenuItemGroup(members: [item('pane.close', 'Close Pane')]),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItemGroup(
              members: [
                item('palette.open', 'Command Palette'),
                item('palette.switcher', 'Switch to Session…'),
                item('sidebar.toggle', 'Toggle Sidebar'),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                item('pane.splitRight', 'Split Right'),
                item('pane.splitDown', 'Split Down'),
                item('pane.maximize', 'Maximize Pane'),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                item('terminal.zoomIn', 'Larger Text'),
                item('terminal.zoomOut', 'Smaller Text'),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Hosts',
          menus: [
            PlatformMenuItemGroup(
              members: [
                item('broadcast.toggle', 'Broadcast to Tab'),
                item('multiExec.open', 'Run on Many Hosts'),
                item('snippets.run', 'Run Snippet…'),
                item('group.open', 'Open Group in Grid…'),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                item('nav.hosts', 'Hosts'),
                item('nav.keys', 'Keys'),
                item('transfers.open', 'Transfers'),
                item('nav.forwards', 'Port Forwards'),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItemGroup(
              members: [
                for (final (index, name) in workspaces.take(9).indexed)
                  item('workspace.${index + 1}', name),
              ],
            ),
            PlatformMenuItemGroup(
              members: [item('workspace.new', 'New Workspace…')],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.minimizeWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.toggleFullScreen,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
