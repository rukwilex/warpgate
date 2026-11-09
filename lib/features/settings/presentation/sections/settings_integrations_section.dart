import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate/features/settings/presentation/settings_controls.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';
import 'package:warpgate/features/settings/presentation/settings_section.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_inline_text.dart';
import 'package:warpgate/features/settings/presentation/widgets/settings_mcp_connect.dart';
import 'package:warpgate/features/settings/utils/mcp_port_parsing.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsIntegrationsSection {
  static SettingsSection build(SettingsControls controls, AppSettings settings) =>
      SettingsSection(
        SettingsSectionIds.integrations,
        'Claude Code',
        WgIcons.bot,
        [
          SettingsItem(
            'Let Claude Code use Warpgate',
            controls.toggle(
              SettingsKeys.mcpEnabled,
              'Let Claude Code use Warpgate',
              value: settings.mcpEnabled,
            ),
            description: PlatformInfo.isMobile
                ? 'Runs an MCP server on this device. On phones and tablets it only runs while Warpgate is on screen'
                : 'Runs an MCP server on 127.0.0.1. Each host decides what Claude Code may do with it',
            keywords: 'mcp integration ai server',
          ),
          SettingsItem(
            'Port',
            SettingsInlineText(
              initial: '${settings.mcpPort}',
              label: 'Port',
              digits: true,
              onSubmitted: (v) => controls.set({
                SettingsKeys.mcpPort: McpPortParsing.parse(
                  v,
                  fallback: settings.mcpPort,
                ),
              }),
            ),
            keywords: 'mcp',
          ),
          SettingsItem(
            'Ask before every change',
            controls.toggle(
              SettingsKeys.mcpAskBeforeMutating,
              'Ask before every change',
              value: settings.mcpAskBeforeMutating,
            ),
            description: 'Shows the exact command or path and waits for you before Claude Code runs or changes anything',
            keywords: 'approval confirm mcp',
          ),
          const SettingsItem(
            'Connect Claude Code',
            SettingsMcpConnect(),
            keywords: 'token command mcp.json',
            stacked: true,
          ),
        ],
      );
}
