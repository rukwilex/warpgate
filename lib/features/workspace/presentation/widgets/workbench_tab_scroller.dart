import 'package:flutter/material.dart';

class WorkbenchTabScroller extends StatefulWidget {
  const new({
    required this.activeIndex,
    required this.tabWidth,
    required this.builder,
    super.key,
  });

  final int activeIndex;
  final double tabWidth;
  final Widget Function(ScrollController scroll) builder;

  @override
  State<WorkbenchTabScroller> createState() => _WorkbenchTabScrollerState();
}

class _WorkbenchTabScrollerState extends State<WorkbenchTabScroller> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(WorkbenchTabScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex ||
        oldWidget.tabWidth != widget.tabWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    if (!mounted || !_scroll.hasClients || widget.activeIndex < 0) return;
    final position = _scroll.position;
    final start = widget.activeIndex * widget.tabWidth;
    final end = start + widget.tabWidth;
    final viewport = position.viewportDimension;
    var target = position.pixels;
    if (start < target) target = start;
    if (end > target + viewport) target = end - viewport;
    target = target.clamp(0, position.maxScrollExtent);
    if (target != position.pixels) _scroll.jumpTo(target);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_scroll);
}
