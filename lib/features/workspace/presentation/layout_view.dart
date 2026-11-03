import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';
import 'package:warpgate/features/workspace/domain/workspace.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

typedef PaneBuilder = Widget Function(BuildContext context, String paneId);

class LayoutView extends StatelessWidget {
  const new({required this.tab, required this.paneBuilder, super.key});

  final WorkspaceTab tab;
  final PaneBuilder paneBuilder;

  @override
  Widget build(BuildContext context) {
    final maximized = tab.maximizedPaneId;
    if (maximized != null && tab.panes.containsKey(maximized)) {
      return KeyedSubtree(
        key: ValueKey(maximized),
        child: paneBuilder(context, maximized),
      );
    }
    final root = tab.root;
    if (root == null) return const SizedBox.shrink();
    return _NodeView(tabId: tab.id, node: root, paneBuilder: paneBuilder);
  }
}

class _NodeView extends StatelessWidget {
  const new({
    required this.tabId,
    required this.node,
    required this.paneBuilder,
  });

  final String tabId;
  final LayoutNode node;
  final PaneBuilder paneBuilder;

  @override
  Widget build(BuildContext context) => switch (node) {
    LeafNode(:final paneId) => KeyedSubtree(
      key: ValueKey(paneId),
      child: paneBuilder(context, paneId),
    ),
    final SplitNode split => _SplitView(
      tabId: tabId,
      split: split,
      paneBuilder: paneBuilder,
    ),
  };
}

class _SplitView extends ConsumerWidget {
  const new({
    required this.tabId,
    required this.split,
    required this.paneBuilder,
  });

  final String tabId;
  final SplitNode split;
  final PaneBuilder paneBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizontal = split.axis == SplitAxis.horizontal;
    final hit = context.sizes.splitterHit;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final available = (extent - hit).clamp(0.0, double.infinity);
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final firstExtent =
            (available * split.ratio * ratio).roundToDouble() / ratio;
        final firstChild = _NodeView(
          tabId: tabId,
          node: split.first,
          paneBuilder: paneBuilder,
        );
        final secondChild = _NodeView(
          tabId: tabId,
          node: split.second,
          paneBuilder: paneBuilder,
        );
        final divider = PaneDivider(
          horizontal: horizontal,
          ratio: split.ratio,
          onDrag: (delta) {
            if (available <= 0) return;
            final minRatio = (context.sizes.paneMin / available).clamp(
              Layouts.minRatio,
              0.45,
            );
            final next = (split.ratio + delta / available).clamp(
              minRatio,
              1 - minRatio,
            );
            ref
                .read(workbenchProvider.notifier)
                .setRatio(tabId, split.id, next);
          },
          onStep: (delta) => ref
              .read(workbenchProvider.notifier)
              .setRatio(tabId, split.id, split.ratio + delta),
          onReset: () => ref
              .read(workbenchProvider.notifier)
              .setRatio(tabId, split.id, 0.5),
          onDragEnd: () => ref.read(terminalSessionsProvider).settleSizes(),
        );
        return Flex(
          direction: horizontal ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: horizontal ? firstExtent : null,
              height: horizontal ? null : firstExtent,
              child: firstChild,
            ),
            divider,
            Expanded(child: secondChild),
          ],
        );
      },
    );
  }
}

class PaneDivider extends StatefulWidget {
  const new({
    required this.horizontal,
    required this.ratio,
    required this.onDrag,
    required this.onStep,
    required this.onReset,
    super.key,
    this.onDragEnd,
    this.label,
  });

  final bool horizontal;
  final double ratio;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onStep;
  final VoidCallback onReset;
  final VoidCallback? onDragEnd;
  final String? label;

  @override
  State<PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<PaneDivider> {
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  void _endDrag() {
    setState(() => _dragging = false);
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sizes = context.sizes;
    final active = _hovered || _dragging || _focused;
    final line = active ? colors.accent : colors.hairline;
    const step = WorkbenchController.resizeStep;
    final decrease = widget.horizontal
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowUp;
    final increase = widget.horizontal
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowDown;
    return Semantics(
      slider: true,
      label:
          widget.label ??
          (widget.horizontal
              ? 'Resize panes left and right'
              : 'Resize panes up and down'),
      value: '${(widget.ratio * 100).round()} percent',
      increasedValue: '${((widget.ratio + step) * 100).round()} percent',
      decreasedValue: '${((widget.ratio - step) * 100).round()} percent',
      onIncrease: () => widget.onStep(step),
      onDecrease: () => widget.onStep(-step),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        mouseCursor: widget.horizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        shortcuts: {
          SingleActivator(decrease): const _StepIntent(-1),
          SingleActivator(increase): const _StepIntent(1),
        },
        actions: {
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (intent) {
              widget.onStep(step * intent.direction);
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onReset,
          onHorizontalDragStart: widget.horizontal
              ? (_) => setState(() => _dragging = true)
              : null,
          onHorizontalDragUpdate: widget.horizontal
              ? (details) => widget.onDrag(details.delta.dx)
              : null,
          onHorizontalDragEnd: widget.horizontal ? (_) => _endDrag() : null,
          onVerticalDragStart: widget.horizontal
              ? null
              : (_) => setState(() => _dragging = true),
          onVerticalDragUpdate: widget.horizontal
              ? null
              : (details) => widget.onDrag(details.delta.dy),
          onVerticalDragEnd: widget.horizontal ? null : (_) => _endDrag(),
          child: SizedBox(
            width: widget.horizontal ? sizes.splitterHit : null,
            height: widget.horizontal ? null : sizes.splitterHit,
            child: Center(
              child: Container(
                width: widget.horizontal
                    ? (active ? sizes.markerBar : sizes.hairline)
                    : null,
                height: widget.horizontal
                    ? null
                    : (active ? sizes.markerBar : sizes.hairline),
                color: line,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIntent extends Intent {
  const new(this.direction);

  final int direction;
}
