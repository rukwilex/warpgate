import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/shell/presentation/shell_destinations.dart';
import 'package:warpgate/features/shell/presentation/shell_layout.dart';
import 'package:warpgate/features/shell/presentation/widgets/shell_host_list.dart';
import 'package:warpgate/features/shell/utils/shell_section.dart';

class ShellSidebar extends ConsumerWidget {
  const new({
    required this.location,
    required this.rail,
    required this.paletteButton,
    super.key,
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
    final section = shellSection(location);
    final registry = ref.read(commandRegistryProvider);
    final nav = [
      for (final destination in shellDestinations)
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
            if (!rail) const Expanded(child: ShellHostList()) else const Spacer(),
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
