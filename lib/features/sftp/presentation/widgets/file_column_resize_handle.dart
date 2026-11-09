import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class FileColumnResizeHandle extends StatefulWidget {
  const new({required this.label, required this.onDrag, super.key});

  final String label;
  final ValueChanged<double> onDrag;

  @override
  State<FileColumnResizeHandle> createState() => _FileColumnResizeHandleState();
}

class _FileColumnResizeHandleState extends State<FileColumnResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sizes = context.sizes;
    final colors = context.colors;
    return Semantics(
      label: widget.label,
      slider: true,
      onIncrease: () => widget.onDrag(-sizes.treeIndent),
      onDecrease: () => widget.onDrag(sizes.treeIndent),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
          child: SizedBox(
            width: sizes.splitterHit,
            child: Center(
              child: Container(
                width: sizes.hairline,
                height: sizes.icon,
                color: _hovered ? colors.accent : colors.hairline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
