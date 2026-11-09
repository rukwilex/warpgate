import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_shortcut_list.dart';

abstract final class SettingsShortcutsSection {
  static SettingsSection build() => const SettingsSection(
    SettingsSectionIds.shortcuts,
    'Shortcuts',
    WgIcons.keyboard,
    [
      SettingsItem(
        'Keyboard shortcuts',
        SettingsShortcutList(),
        keywords: 'keys bindings rebind hotkeys',
        stacked: true,
      ),
    ],
  );
}
