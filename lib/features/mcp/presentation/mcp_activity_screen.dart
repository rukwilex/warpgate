import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate_core/core/util/format.dart';

class McpActivityScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(mcpActivityProvider);
    final server = ref.watch(mcpServerProvider);
    final colors = context.colors;
    return WgPage(
      title: 'Claude Code activity',
      subtitle: server.running
          ? 'Server on port ${server.port}'
          : 'Server is off',
      leading: WgIconButton(
        icon: WgIcons.arrowLeft,
        label: 'Back to settings',
        onPressed: () => GoRouter.of(context).go(Routes.settings),
      ),
      actions: [
        if (entries.isNotEmpty)
          WgButton.ghost(
            label: 'Clear log',
            onPressed: () =>
                unawaited(ref.read(mcpActivityProvider.notifier).clear()),
          ),
      ],
      empty: entries.isEmpty
          ? const WgEmptyState(
              icon: WgIcons.bot,
              title: 'No activity yet',
              body: 'Every tool call from Claude Code appears here with its time, arguments and result.',
            )
          : null,
      child: entries.isEmpty
          ? null
          : Column(
              children: [
                for (final entry in entries)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: context.space.md),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.hairline),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: context.sizes.metaColumn,
                          child: Text(
                            Format.clock(entry.at),
                            style: context.type.monoSmall,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            top: context.space.xs,
                            right: context.space.sm,
                          ),
                          child: WgStatusDot(
                            state: entry.ok
                                ? WgDotState.connected
                                : WgDotState.dropped,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.tool, style: context.type.mono),
                              SizedBox(height: context.space.hair),
                              SelectableText(
                                entry.arguments,
                                style: context.type.monoSmall.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              SizedBox(height: context.space.hair),
                              Text(
                                entry.summary,
                                style: context.type.caption.copyWith(
                                  color: entry.ok
                                      ? colors.textSecondary
                                      : colors.negative,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
