import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/cli/presentation/command_line_settings.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';

abstract final class SettingsCommandLineSection {
  static SettingsSection build() => const SettingsSection(
    SettingsSectionIds.commandLine,
    'Command line',
    WgIcons.commandLine,
    [
      SettingsItem(
        'warpgate command',
        CommandLineSettings(),
        description: 'Use your hosts, files and sessions from a terminal',
        keywords: 'cli install path shell terminal',
        stacked: true,
      ),
    ],
  );
}
