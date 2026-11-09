import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_inline_text.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_stepper.dart';
import 'package:warpgate/features/settings/utils/settings_option_lists.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsFilesSection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.files,
        'Files and transfers',
        WgIcons.transfer,
        [
          SettingsItem(
            'Transfers at once',
            SettingsStepper(
              value: settings.transferConcurrency,
              min: SettingsLimits.transfersMin,
              max: SettingsLimits.transfersMax,
              label: 'Transfers at once',
              onChanged: (v) {
                controls.set({SettingsKeys.transferConcurrency: v});
                controls.ref
                    .read(transferQueueProvider.notifier)
                    .rescheduleAfterSettingsChange();
              },
            ),
            keywords: 'concurrency parallel',
          ),
          SettingsItem(
            'When a file already exists',
            controls.segmented(
              settings.conflictPolicy,
              SettingsOptionLists.conflictPolicies(),
              (v) => controls.set({SettingsKeys.conflictPolicy: v.name}),
              'When a file already exists',
            ),
            keywords: 'conflict overwrite skip rename',
            stacked: true,
          ),
          SettingsItem(
            'Offer direct copy between hosts',
            controls.toggle(
              SettingsKeys.offerDirectMode,
              'Offer direct copy between hosts',
              value: settings.offerDirectMode,
            ),
            description: 'When you copy from one host to another, check whether the source can reach the target with rsync or scp',
            keywords: 'rsync scp direct',
          ),
          SettingsItem(
            'Show hidden files',
            controls.toggle(
              SettingsKeys.showHiddenFiles,
              'Show hidden files',
              value: settings.showHiddenFiles,
            ),
            description: 'Default for new file panes',
            keywords: 'dotfiles',
          ),
          SettingsItem(
            'Start remote panes in',
            SettingsInlineText(
              initial: settings.defaultRemotePath,
              label: 'Start remote panes in',
              onSubmitted: (v) => controls.set({
                SettingsKeys.defaultRemotePath: v.isEmpty
                    ? SettingsDefaults.homePath
                    : v,
              }),
            ),
            keywords: 'default path',
            stacked: true,
          ),
          SettingsItem(
            'Start local panes in',
            SettingsInlineText(
              initial: settings.defaultLocalPath ?? SettingsDefaults.homePath,
              label: 'Start local panes in',
              onSubmitted: (v) => controls.set({
                SettingsKeys.defaultLocalPath: v.isEmpty ? null : v,
              }),
            ),
            keywords: 'default path',
            stacked: true,
          ),
        ],
      );
}
