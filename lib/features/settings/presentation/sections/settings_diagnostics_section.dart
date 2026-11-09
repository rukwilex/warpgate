import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/diagnostic_actions.dart';
import 'package:warpgate/features/settings/presentation/widgets/diagnostic_readout.dart';
import 'package:warpgate/features/settings/presentation/widgets/session_memory_list.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_stepper.dart';
import 'package:warpgate/features/settings/presentation/widgets/stall_list.dart';
import 'package:warpgate/features/settings/utils/diagnostic_text.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsDiagnosticsSection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.diagnostics,
        'Diagnostics',
        WgIcons.activity,
        [
          const SettingsItem(
            'Memory',
            DiagnosticReadout(DiagnosticText.memory, label: 'Memory'),
            description: 'In use now, and the part held by terminal scrollback',
            keywords: 'ram rss leak performance',
          ),
          SettingsItem(
            'SSH engine',
            controls.segmented(
              settings.sshEngine,
              SettingsOptions.sshEngine,
              (v) => controls.set({SettingsKeys.sshEngine: v}),
              'SSH engine',
            ),
            description: NativeEngine.available
                ? 'Native runs SSH and SFTP outside the window thread and is many times faster. Applies to new connections'
                : 'The native engine could not be loaded on this device, so Dart is used',
            keywords: 'rust russh dartssh2 performance encryption',
          ),
          SettingsItem(
            'Memory limit',
            SettingsStepper(
              value: settings.memorySoftLimitMb,
              min: SettingsLimits.memoryLimitMinMb,
              max: SettingsLimits.memoryLimitMaxMb,
              step: SettingsLimits.memoryLimitStepMb,
              unit: 'MB',
              label: 'Memory limit',
              onChanged: (v) =>
                  controls.set({SettingsKeys.memorySoftLimitMb: v}),
            ),
            description: 'Above this, Warpgate clears caches and shortens scrollback in panes you are not looking at',
            keywords: 'ram soft limit trim',
          ),
          const SettingsItem(
            'CPU',
            DiagnosticReadout(DiagnosticText.cpu, label: 'CPU'),
            description: 'Average over the last 10 seconds',
            keywords: 'processor load performance',
          ),
          const SettingsItem(
            'Responsiveness',
            DiagnosticReadout(DiagnosticText.latency, label: 'Responsiveness'),
            description: 'How late the app answered in the last minute. Under 16 ms feels instant',
            keywords: 'latency event loop freeze lag',
          ),
          const SettingsItem(
            'Frames',
            DiagnosticReadout(DiagnosticText.frames, label: 'Frames'),
            description: 'Frames that took longer than one screen refresh since the app started',
            keywords: 'jank fps smooth',
          ),
          const SettingsItem(
            'Connections',
            DiagnosticReadout(DiagnosticText.links, label: 'Connections'),
            description: 'Open SSH connections, terminals and running transfers',
            keywords: 'sessions channels sockets',
          ),
          const SettingsItem(
            'Background work',
            DiagnosticReadout(DiagnosticText.workers, label: 'Background work'),
            description: 'Helper threads running next to the window',
            keywords: 'isolates threads workers',
          ),
          const SettingsItem(
            'Terminals by memory',
            SessionMemoryList(),
            description: 'Scrollback held by each open terminal',
            keywords: 'sessions per session memory scrollback',
            stacked: true,
          ),
          const SettingsItem(
            'Recent stalls',
            StallList(),
            description:
                'Times the app stopped answering for more than 2 seconds',
            keywords: 'freeze hang watchdog',
            stacked: true,
          ),
          const SettingsItem(
            'Report',
            DiagnosticActions(),
            description: 'Everything on this page, with recent log lines, as a JSON file for a bug report',
            keywords: 'export free memory diagnostics',
            stacked: true,
          ),
        ],
      );
}
