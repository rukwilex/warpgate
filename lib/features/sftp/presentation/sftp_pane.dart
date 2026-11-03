import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/sftp/presentation/file_browser.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/pane_frame.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

class SftpPane extends ConsumerWidget {
  const new({required this.pane, super.key, this.compactChrome = false});

  final Pane pane;
  final bool compactChrome;

  String _label(WidgetRef ref, SftpSide side) => side.isLocal
      ? 'This device'
      : ref.watch(hostsProvider).value?.host(side.hostId)?.label ??
            'Removed host';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = pane.content as SftpContent;
    final bench = ref.read(workbenchProvider.notifier);
    final links = ref.watch(hostLinksProvider);
    final left = content.left;
    final right = content.right;
    final title = right == null
        ? 'Files · ${_label(ref, left)}'
        : '${_label(ref, left)} and ${_label(ref, right)}';
    final dot = left.hostId == null
        ? (right?.hostId == null
              ? WgDotState.connected
              : (links[right!.hostId]?.state ?? LinkState.idle).dot)
        : (links[left.hostId]?.state ?? LinkState.idle).dot;
    void update(SftpContent next) => bench.updatePane(pane.id, next);
    final leftBrowser = FileBrowser(
      key: ValueKey('${pane.id}-left-${left.hostId}'),
      side: left,
      paneKey: '${pane.id}-left',
      copyTarget: right,
      copyLabel: right == null ? null : _label(ref, right),
      onSideChanged: (side) => update(content.copyWith(left: side)),
    );
    return PaneFrame(
      pane: pane,
      title: title,
      dot: dot,
      compact: compactChrome,
      menu: [
        if (right == null)
          WgMenuEntry(
            label: 'Show second side',
            icon: WgIcons.arrowLeftRight,
            onSelected: () =>
                update(content.copyWith(right: () => const SftpSide())),
          )
        else ...[
          WgMenuEntry(
            label: 'Swap sides',
            icon: WgIcons.swap,
            onSelected: () => update(SftpContent(left: right, right: left)),
          ),
          WgMenuEntry(
            label: 'Hide second side',
            icon: WgIcons.close,
            onSelected: () => update(content.copyWith(right: () => null)),
          ),
        ],
      ],
      child: right == null
          ? leftBrowser
          : LayoutBuilder(
              builder: (context, constraints) {
                final rightBrowser = FileBrowser(
                  key: ValueKey('${pane.id}-right-${right.hostId}'),
                  side: right,
                  paneKey: '${pane.id}-right',
                  copyTarget: left,
                  copyLabel: _label(ref, left),
                  onSideChanged: (side) =>
                      update(content.copyWith(right: () => side)),
                );
                final stacked = constraints.maxWidth < context.sizes.dialogWide;
                return Flex(
                  direction: stacked ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: leftBrowser),
                    WgHairline(vertical: !stacked),
                    Expanded(child: rightBrowser),
                  ],
                );
              },
            ),
    );
  }
}
