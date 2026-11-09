import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate/features/shell/presentation/widgets/status_bar_item.dart';
import 'package:warpgate/features/shell/presentation/widgets/transfer_indicator.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';

class StatusBar extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final links = ref.watch(hostLinksProvider);
    final bench = ref.watch(workbenchProvider);
    final mcp = ref.watch(mcpServerProvider);
    final forwards = ref.watch(activeForwardsProvider);
    final connected = links.values.where((link) => link.isUsable).length;
    final reconnecting = links.values
        .where((link) => link.state == LinkState.connecting)
        .length;
    final dropped = links.values
        .where((link) => link.state == LinkState.dropped)
        .length;
    final broadcast = bench.broadcastPaneIds.length;
    final activeForwards = forwards
        .where((forward) => forward.state == ForwardState.active)
        .length;
    final meta = context.type.monoSmall.copyWith(color: colors.textMuted);
    return Container(
      height: context.sizes.statusBar,
      padding: EdgeInsets.symmetric(horizontal: space.sm),
      decoration: BoxDecoration(
        color: colors.canvasDeep,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: [
          StatusBarItem(
            label:
                '$connected connected${reconnecting > 0 ? ', $reconnecting connecting' : ''}${dropped > 0 ? ', $dropped dropped' : ''}',
            onPressed: () => GoRouter.of(context).go(Routes.hosts),
            child: Row(
              children: [
                WgStatusDot(
                  state: dropped > 0
                      ? WgDotState.dropped
                      : connected > 0
                      ? WgDotState.connected
                      : WgDotState.idle,
                ),
                SizedBox(width: space.sm),
                Text(
                  '$connected connected${reconnecting > 0 ? ' · $reconnecting connecting' : ''}${dropped > 0 ? ' · $dropped dropped' : ''}',
                  style: meta,
                ),
              ],
            ),
          ),
          if (broadcast > 1) ...[
            SizedBox(width: space.md),
            StatusBarItem(
              label: 'Broadcasting to $broadcast panes. Stop',
              onPressed: () =>
                  ref.read(workbenchProvider.notifier).setBroadcast(const {}),
              child: Row(
                children: [
                  Icon(
                    WgIcons.broadcast,
                    size: context.sizes.icon,
                    color: colors.accentInk,
                  ),
                  SizedBox(width: space.xs),
                  Text(
                    'Broadcast · $broadcast panes',
                    style: meta.copyWith(color: colors.accentInk),
                  ),
                ],
              ),
            ),
          ],
          if (activeForwards > 0) ...[
            SizedBox(width: space.md),
            StatusBarItem(
              label: '$activeForwards port forwards active',
              onPressed: () => GoRouter.of(context).go(Routes.forwards),
              child: Row(
                children: [
                  Icon(
                    WgIcons.forward,
                    size: context.sizes.icon,
                    color: colors.textMuted,
                  ),
                  SizedBox(width: space.xs),
                  Text('$activeForwards forwards', style: meta),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (mcp.running) ...[
            StatusBarItem(
              label:
                  'Claude Code server running on port ${mcp.port}. Open activity',
              onPressed: () => GoRouter.of(context).go(Routes.mcpActivity),
              child: Row(
                children: [
                  Icon(
                    WgIcons.bot,
                    size: context.sizes.icon,
                    color: colors.textMuted,
                  ),
                  SizedBox(width: space.xs),
                  Text('MCP :${mcp.port}', style: meta),
                ],
              ),
            ),
            SizedBox(width: space.md),
          ],
          const TransferIndicator(),
        ],
      ),
    );
  }
}
