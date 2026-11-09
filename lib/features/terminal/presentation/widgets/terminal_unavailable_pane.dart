import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/workspace/presentation/pane_frame.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

class TerminalUnavailablePane extends StatelessWidget {
  const new({
    required this.pane,
    required this.loading,
    required this.title,
    super.key,
  });

  final Pane pane;
  final bool loading;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return PaneFrame(
        pane: pane,
        title: 'Loading',
        dot: WgDotState.connecting,
        child: const WgSkeletonList(label: 'Loading hosts'),
      );
    }
    return PaneFrame(
      pane: pane,
      title: title,
      dot: WgDotState.dropped,
      child: const WgEmptyState(
        icon: WgIcons.server,
        title: 'This host was removed',
        body: 'The pane points at a host that is no longer saved. Close it, or add the host again.',
      ),
    );
  }
}
