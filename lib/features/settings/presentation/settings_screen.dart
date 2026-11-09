import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_about_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_appearance_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_backup_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_command_line_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_diagnostics_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_files_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_integrations_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_security_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_sessions_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_shortcuts_section.dart';
import 'package:warpgate/features/settings/presentation/sections/settings_terminal_section.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_row.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _query = '';
  String _section = SettingsSectionIds.appearance;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sections = _sections(context, settings);
    final query = _query.trim();
    final wide = MediaQuery.sizeOf(context).width >= WgBreakpoints.expanded;
    final visible = query.isEmpty
        ? (wide
              ? sections.where((section) => section.id == _section).toList()
              : sections)
        : [
            for (final section in sections)
              if (section.items.any((item) => item.matches(query)))
                SettingsSection(
                  section.id,
                  section.title,
                  section.icon,
                  section.items.where((item) => item.matches(query)).toList(),
                ),
          ];
    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        context.space.xxl,
        context.space.xl,
        context.space.xxl,
        context.space.huge,
      ),
      children: [
        if (!wide) ...[
          Semantics(
            header: true,
            child: Text('Settings', style: context.type.heading),
          ),
          SizedBox(height: context.space.lg),
          _search(),
        ],
        if (visible.isEmpty)
          WgEmptyState(
            title: 'No settings match "$query"',
            body: 'Try a shorter word, like theme, tmux or port.',
          ),
        for (final section in visible) ...[
          Padding(
            padding: EdgeInsets.only(
              top: context.space.xl,
              bottom: context.space.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(section.title, style: context.type.title),
            ),
          ),
          for (final item in section.items) SettingsRow(item: item),
        ],
      ],
    );
    if (!wide) return content;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: context.sizes.sidebar,
          child: ListView(
            padding: EdgeInsets.all(context.space.md),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.space.sm,
                  context.space.sm,
                  0,
                  context.space.lg,
                ),
                child: Semantics(
                  header: true,
                  child: Text('Settings', style: context.type.heading),
                ),
              ),
              _search(),
              SizedBox(height: context.space.md),
              for (final section in sections)
                Padding(
                  padding: EdgeInsets.only(bottom: context.space.hair),
                  child: WgListRow(
                    title: section.title,
                    dense: true,
                    leading: Icon(section.icon),
                    selected: query.isEmpty && section.id == _section,
                    onPressed: () => setState(() {
                      _section = section.id;
                      _query = '';
                    }),
                  ),
                ),
            ],
          ),
        ),
        const WgHairline(vertical: true),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.sizes.sheetMax + context.space.huge,
              ),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  Widget _search() => WgTextField(
    key: const ValueKey('settings-search'),
    placeholder: 'Search settings',
    leadingIcon: WgIcons.search,
    onChanged: (value) => setState(() => _query = value),
  );

  List<SettingsSection> _sections(BuildContext context, AppSettings settings) {
    final controls = SettingsControls(ref);
    return [
      SettingsAppearanceSection.build(controls, settings),
      SettingsTerminalSection.build(controls, settings),
      SettingsSessionsSection.build(controls, settings),
      SettingsFilesSection.build(controls, settings),
      SettingsShortcutsSection.build(),
      SettingsSecuritySection.build(controls, settings),
      SettingsIntegrationsSection.build(controls, settings),
      if (PlatformInfo.isDesktop) SettingsCommandLineSection.build(),
      SettingsBackupSection.build(),
      SettingsDiagnosticsSection.build(controls, settings),
      SettingsAboutSection.build(context),
    ];
  }
}
