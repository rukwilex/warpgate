import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_backup_actions.dart';

abstract final class SettingsBackupSection {
  static SettingsSection build() => const SettingsSection(
    SettingsSectionIds.backup,
    'Backup',
    WgIcons.archive,
    [
      SettingsItem(
        'Encrypted backup',
        SettingsBackupActions(),
        description: 'Hosts, snippets, workspaces and settings, locked with a passphrase you choose',
        keywords: 'export import restore',
        stacked: true,
      ),
    ],
  );
}
