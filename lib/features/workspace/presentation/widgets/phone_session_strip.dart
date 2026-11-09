import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

class PhoneSessionStrip extends ConsumerWidget {
  const new({
    required this.panes,
    required this.current,
    required this.onSelect,
    super.key,
  });

  final List<Pane> panes;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(hostsProvider).value;
    final sessions = ref.watch(terminalSessionsProvider);
    final links = ref.watch(hostLinksProvider);
    return Container(
      height: context.sizes.touchTarget,
      decoration: BoxDecoration(
        color: context.colors.canvasDeep,
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.space.xs),
        itemCount: panes.length + 1,
        itemBuilder: (context, index) {
          if (index == panes.length) {
            return WgIconButton(
              icon: WgIcons.plus,
              label: 'New terminal',
              onPressed: () =>
                  unawaited(ref.read(commandRegistryProvider).newSession()),
            );
          }
          final pane = panes[index];
          final hostId = pane.content.hostId;
          final label = switch (pane.content) {
            SshTerminalContent() ||
            LogTailContent() => catalog?.host(hostId)?.label ?? 'Removed host',
            LocalTerminalContent() => 'Local',
            SftpContent() => 'Files',
          };
          final state =
              sessions[pane.id]?.status.value.state ??
              (hostId == null
                  ? LinkState.connected
                  : links[hostId]?.state ?? LinkState.idle);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.space.hair,
              vertical: context.space.xs,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: context.sizes.tabMin,
                maxWidth: context.sizes.tabMax,
              ),
              child: WgTabChip(
                label: label,
                selected: index == current,
                leading: WgStatusDot(state: state.dot, subject: label),
                onPressed: () => onSelect(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
