import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_known_hosts.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_lock_toggle.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsSecuritySection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.security,
        'Security',
        WgIcons.shield,
        [
          const SettingsItem(
            'Lock Warpgate',
            SettingsLockToggle(),
            description: 'Asks for a PIN or biometrics when you return',
            keywords: 'pin biometrics face touch',
          ),
          if (settings.appLock) ...[
            SettingsItem(
              'Unlock with biometrics',
              controls.toggle(
                SettingsKeys.biometricUnlock,
                'Unlock with biometrics',
                value: settings.biometricUnlock,
              ),
              keywords: 'face touch fingerprint',
            ),
            SettingsItem(
              'Lock after',
              controls.segmented(
                settings.autoLockMinutes,
                SettingsOptions.autoLockMinutes,
                (v) => controls.set({SettingsKeys.autoLockMinutes: v}),
                'Lock after',
              ),
              description: 'Of inactivity or time in the background',
              keywords: 'timeout auto',
            ),
          ],
          SettingsItem(
            'Clear copied secrets after',
            controls.segmented(
              settings.clipboardClearSeconds,
              SettingsOptions.clipboardClearSeconds,
              (v) => controls.set({SettingsKeys.clipboardClearSeconds: v}),
              'Clear copied secrets after',
            ),
            description: 'Applies to tokens and keys copied from Warpgate',
            keywords: 'clipboard',
            stacked: true,
          ),
          const SettingsItem(
            'Known hosts',
            SettingsKnownHosts(),
            keywords: 'fingerprint host key trust',
            stacked: true,
          ),
        ],
      );
}
