import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/util/clipboard_guard.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/settings/utils/mcp_connect_snippets.dart';
import 'package:warpgate/features/settings/utils/mcp_token_mask.dart';
import 'package:warpgate_core/core/util/format.dart';

class SettingsMcpConnect extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final server = ref.watch(mcpServerProvider);
    final token = server.token ?? '…';
    final url = server.endpoint(settings.mcpPort);
    final command = McpConnectSnippets.httpCommand(url, token);
    final json = McpConnectSnippets.mcpJson(url, token);
    final clear = Duration(seconds: settings.clipboardClearSeconds);
    final status = server.running
        ? WgInlineMessage(tone: WgTone.positive, message: 'Listening on $url')
        : server.error != null
        ? WgInlineMessage(tone: WgTone.negative, message: server.error!)
        : const WgInlineMessage(
            message: 'Off. Turn it on above to let Claude Code connect.',
          );
    Widget block(String label, String text, {required bool secret}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.space.md),
        Row(
          children: [
            Expanded(child: Text(label, style: context.type.caption)),
            WgButton.ghost(
              label: 'Copy',
              icon: WgIcons.copy,
              onPressed: () async {
                await ClipboardGuard.copySecret(
                  text,
                  clearAfter: secret ? clear : Duration.zero,
                );
                if (context.mounted) {
                  showWgToast(
                    context,
                    secret && clear > Duration.zero
                        ? 'Copied. The clipboard clears in ${Format.duration(clear)}'
                        : 'Copied',
                  );
                }
              },
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(context.space.md),
          decoration: BoxDecoration(
            color: context.colors.canvasDeep,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: context.colors.hairline),
          ),
          child: SelectableText(
            text,
            style: context.type.monoSmall.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
    final masked = McpTokenMask.mask(token);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        SizedBox(height: context.space.md),
        Row(
          children: [
            Text('Token', style: context.type.body),
            SizedBox(width: context.space.md),
            Expanded(child: Text(masked, style: context.type.mono)),
            WgButton.ghost(
              label: 'Copy',
              icon: WgIcons.copy,
              onPressed: () => unawaited(
                ClipboardGuard.copySecret(token, clearAfter: clear),
              ),
            ),
            WgButton.ghost(
              label: 'Regenerate',
              icon: WgIcons.refresh,
              onPressed: () async {
                final ok = await showWgConfirm(
                  context,
                  title: 'Regenerate the token?',
                  message: 'Claude Code stops working with Warpgate until you add the new token to it.',
                  confirmLabel: 'Regenerate',
                  destructive: true,
                );
                if (ok) {
                  await ref.read(mcpServerProvider.notifier).regenerateToken();
                }
              },
            ),
          ],
        ),
        block('Run this in a terminal', command, secret: true),
        block('Or add this to .mcp.json', json, secret: true),
        if (PlatformInfo.isDesktop)
          block(
            'For stdio, build the companion in tool/mcp_stdio and register it',
            McpConnectSnippets.stdioCommand(token, settings.mcpPort),
            secret: true,
          ),
        SizedBox(height: context.space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: WgButton(
            label: 'Activity log',
            icon: WgIcons.scrollText,
            onPressed: () => GoRouter.of(context).go(Routes.mcpActivity),
          ),
        ),
      ],
    );
  }
}
