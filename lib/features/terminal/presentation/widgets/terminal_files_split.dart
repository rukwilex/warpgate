import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/utils/files_split_ratio.dart';
import 'package:warpgate/features/workspace/presentation/layout_view.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

class TerminalFilesSplit extends StatelessWidget {
  const new({
    required this.files,
    required this.terminal,
    required this.browser,
    required this.onFilesChanged,
    required this.onDragEnd,
    super.key,
  });

  final AttachedFiles files;
  final Widget terminal;
  final Widget browser;
  final ValueChanged<AttachedFiles Function(AttachedFiles files)> onFilesChanged;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final horizontal = files.dock == FilesDock.right;
    final sizes = context.sizes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final available = math.max(extent - sizes.splitterHit, 0);
        double clampRatio(double ratio) => clampFilesSplitRatio(
          ratio,
          available: available.toDouble(),
          terminalMin: sizes.terminalMin,
          filesPanelMin: sizes.filesPanelMin,
        );

        final ratio = clampRatio(files.ratio);
        final pixel = MediaQuery.devicePixelRatioOf(context);
        final first = (available * ratio * pixel).roundToDouble() / pixel;
        return Flex(
          direction: horizontal ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: horizontal ? first : null,
              height: horizontal ? null : first,
              child: terminal,
            ),
            PaneDivider(
              horizontal: horizontal,
              ratio: ratio,
              label: horizontal
                  ? 'Resize terminal and files left and right'
                  : 'Resize terminal and files up and down',
              onDrag: (delta) {
                if (available <= 0) return;
                onFilesChanged(
                  (files) => files.copyWith(
                    ratio: clampRatio(files.ratio + delta / available),
                  ),
                );
              },
              onStep: (delta) => onFilesChanged(
                (files) =>
                    files.copyWith(ratio: clampRatio(files.ratio + delta)),
              ),
              onReset: () => onFilesChanged(
                (files) => files.copyWith(ratio: const AttachedFiles().ratio),
              ),
              onDragEnd: onDragEnd,
            ),
            Expanded(child: browser),
          ],
        );
      },
    );
  }
}
