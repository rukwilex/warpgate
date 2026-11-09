import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_shortcut_record_dialog.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';

class SettingsShortcutList extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref
        .read(commandRegistryProvider)
        .commands()
        .where((command) => command.rebindable)
        .toList();
    final overrides = ref.watch(
      settingsProvider.select((s) => s.shortcutOverrides),
    );
    final keys = ref.watch(shortcutMapProvider);
    return Column(
      children: [
        for (final command in commands)
          WgListRow(
            title: command.title,
            dense: true,
            meta: overrides.containsKey(command.id) ? 'changed' : null,
            semanticLabel:
                '${command.title}, ${keys[command.id] == null ? 'no shortcut' : WgShortcutLabel.spoken(keys[command.id]!)}. Change',
            onPressed: () =>
                unawaited(_record(context, ref, command.id, command.title)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (keys[command.id] != null)
                  WgKeycap(keys[command.id]!)
                else
                  Text(
                    'None',
                    style: context.type.monoSmall.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                if (overrides.containsKey(command.id))
                  WgIconButton(
                    icon: WgIcons.retry,
                    label: 'Reset ${command.title}',
                    compact: true,
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .resetShortcut(command.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    String id,
    String title,
  ) async {
    ref.read(shortcutsSuspendedProvider.notifier).suspend();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => SettingsShortcutRecordDialog(title: title),
    );
    ref.read(shortcutsSuspendedProvider.notifier).resume();
    if (result == null) return;
    ref.read(settingsProvider.notifier).setShortcut(id, result);
  }
}
