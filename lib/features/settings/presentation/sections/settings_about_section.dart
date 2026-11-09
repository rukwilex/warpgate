import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';

abstract final class SettingsAboutSection {
  static SettingsSection build(BuildContext context) => SettingsSection(
    SettingsSectionIds.about,
    'About',
    WgIcons.info,
    [
      SettingsItem(
        'Warpgate',
        Text(SettingsDefaults.appVersion, style: context.type.mono),
        leading: WgLogoMark(size: context.sizes.iconLarge),
        description: 'SSH and SFTP for many servers at once. Made by kwilex',
        keywords: 'version about logo',
      ),
      SettingsItem(
        'Licenses',
        WgButton.ghost(
          label: 'Show licenses',
          onPressed: () => showLicensePage(
            context: context,
            applicationName: SettingsDefaults.applicationName,
          ),
        ),
        description: 'Geist and JetBrains Mono are under the SIL Open Font License. Icons by Lucide',
      ),
    ],
  );
}
