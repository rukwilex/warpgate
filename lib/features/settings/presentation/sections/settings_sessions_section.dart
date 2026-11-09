import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsSessionsSection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.sessions,
        'Sessions',
        WgIcons.history,
        [
          SettingsItem(
            'Restore on launch',
            controls.toggle(
              SettingsKeys.restoreOnLaunch,
              'Restore on launch',
              value: settings.restoreOnLaunch,
            ),
            description: 'Reopens workspaces, tabs, splits and file paths, then reconnects pane by pane',
            keywords: 'persistence startup',
          ),
          SettingsItem(
            'Reconnect automatically',
            controls.toggle(
              SettingsKeys.autoReconnect,
              'Reconnect automatically',
              value: settings.autoReconnect,
            ),
            description: 'Retries with growing delays, up to 10 times, after the network drops',
          ),
          SettingsItem(
            'Keep scrollback between launches',
            controls.toggle(
              SettingsKeys.persistScrollback,
              'Keep scrollback between launches',
              value: settings.persistScrollback,
            ),
            description:
                'Saves the last ${settings.persistedScrollbackLines} lines of each pane on this device. Turn off for sensitive output',
          ),
          SettingsItem(
            'Use tmux for new hosts',
            controls.toggle(
              SettingsKeys.tmuxByDefault,
              'Use tmux for new hosts',
              value: settings.tmuxByDefault,
            ),
            description: 'New hosts start with server-side persistence on. Each host can change it',
            keywords: 'persistence server',
          ),
        ],
      );
}
