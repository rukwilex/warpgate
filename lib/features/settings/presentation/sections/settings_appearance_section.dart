import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_stepper.dart';
import 'package:warpgate/features/settings/utils/settings_option_lists.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsAppearanceSection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.appearance,
        'Appearance',
        WgIcons.monitor,
        [
          SettingsItem(
            'Theme',
            controls.segmented(
              settings.themeMode,
              SettingsOptions.themeMode,
              (v) => controls.set({SettingsKeys.themeMode: v.name}),
              'Theme',
            ),
            keywords: 'dark light mode',
          ),
          SettingsItem(
            'Accent',
            controls.segmented(
              settings.accent,
              SettingsOptionLists.accents(),
              (v) => controls.set({SettingsKeys.accent: v.name}),
              'Accent',
            ),
            description:
                'Used for focus, selection and the live parts of the interface',
            keywords: 'color',
          ),
          SettingsItem(
            'Terminal colors',
            controls.segmented(
              settings.terminalScheme,
              SettingsOptionLists.terminalSchemes(),
              (v) => controls.set({SettingsKeys.terminalScheme: v.name}),
              'Terminal colors',
            ),
            keywords: 'theme scheme palette',
          ),
          SettingsItem(
            'Terminal text size',
            SettingsStepper(
              value: settings.terminalFontSize.round(),
              min: WgTerminalZoom.min.round(),
              max: WgTerminalZoom.max.round(),
              unit: 'pt',
              label: 'Terminal text size',
              onChanged: (v) =>
                  controls.set({SettingsKeys.terminalFontSize: v.toDouble()}),
            ),
            description:
                'Default for every terminal. To zoom one pane, press ${PlatformInfo.isApple ? 'Cmd' : 'Ctrl'} with + or −, or 0 to reset',
            keywords: 'font zoom',
          ),
          SettingsItem(
            'Density',
            controls.segmented(
              settings.density,
              SettingsOptions.density,
              (v) => controls.set({SettingsKeys.density: v.name}),
              'Density',
            ),
            description:
                'Row height in lists and menus. Touch screens always use 44',
          ),
        ],
      );
}
