import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_stepper.dart';
import 'package:warpgate/features/settings/utils/settings_option_lists.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsTerminalSection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.terminal,
        'Terminal',
        WgIcons.terminal,
        [
          SettingsItem(
            'Scrollback',
            SettingsStepper(
              value: settings.scrollbackLines,
              min: SettingsLimits.scrollbackMin,
              max: SettingsLimits.scrollbackMax,
              step: SettingsLimits.scrollbackStep,
              unit: 'lines',
              label: 'Scrollback',
              onChanged: (v) => controls.set({SettingsKeys.scrollbackLines: v}),
            ),
            description: 'Lines kept per pane. Applies to new panes',
            keywords: 'history buffer',
          ),
          SettingsItem(
            'Cursor',
            controls.segmented(
              settings.cursorShape,
              SettingsOptionLists.cursorShapes(),
              (v) => controls.set({SettingsKeys.cursorShape: v.name}),
              'Cursor',
            ),
          ),
          SettingsItem(
            'Bell',
            controls.segmented(
              settings.bell,
              SettingsOptionLists.bellModes(),
              (v) => controls.set({SettingsKeys.bell: v.name}),
              'Bell',
            ),
          ),
          SettingsItem(
            'Copy on select',
            controls.toggle(
              SettingsKeys.copyOnSelect,
              'Copy on select',
              value: settings.copyOnSelect,
            ),
            description: 'Selected text goes to the clipboard right away',
            keywords: 'clipboard',
          ),
          SettingsItem(
            'Confirm multi-line paste',
            controls.toggle(
              SettingsKeys.confirmMultilinePaste,
              'Confirm multi-line paste',
              value: settings.confirmMultilinePaste,
            ),
            description: 'Shows what will be pasted when it has more than one line, since each line can run as a command',
            keywords: 'clipboard safety',
          ),
        ],
      );
}
