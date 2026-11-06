import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SuggestionPortalController extends OverlayPortalController {
  final _cursorRect = ValueNotifier<Rect>(Rect.zero);

  void update(Rect rect) {
    _cursorRect.value = rect;
    if (!isShowing) show();
  }
}

class SuggestionPortal extends StatefulWidget {
  const SuggestionPortal({
    super.key,
    required this.controller,
    required this.overlayBuilder,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.cursorMargin = const EdgeInsets.all(4),
  });

  final SuggestionPortalController controller;

  final WidgetBuilder overlayBuilder;

  final EdgeInsets padding;

  final EdgeInsets cursorMargin;

  final Widget child;

  @override
  State<SuggestionPortal> createState() => _SuggestionPortalState();
}

class _SuggestionPortalState extends State<SuggestionPortal> {
  @override
  Widget build(BuildContext context) {
    return OverlayPortal.targetsRootOverlay(
      controller: widget.controller,
      overlayChildBuilder: (context) {
        return SuggestionLayout(
          cursorRect: widget.controller._cursorRect,
          padding: widget.padding,
          cursorMargin: widget.cursorMargin,
          child: widget.overlayBuilder(context),
        );
      },
      child: widget.child,
    );
  }
}

class SuggestionLayout extends SingleChildRenderObjectWidget {
  SuggestionLayout({
    super.child,
    required this.cursorRect,
    required this.padding,
    required this.cursorMargin,
  });

  final ValueListenable<Rect> cursorRect;

  final EdgeInsets padding;

  final EdgeInsets cursorMargin;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCompletionLayout(
      null,
      cursorRect: cursorRect,
      padding: padding,
      cursorMargin: cursorMargin,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCompletionLayout renderObject,
  ) {
    renderObject.cursorRect = cursorRect;
    renderObject.padding = padding;
    renderObject.cursorMargin = cursorMargin;
  }
}

class RenderCompletionLayout extends RenderShiftedBox {
  RenderCompletionLayout(
    super.child, {
    required ValueListenable<Rect> cursorRect,
    required EdgeInsets padding,
    required EdgeInsets cursorMargin,
  })  : _cursorRect = cursorRect,
        _padding = padding,
        _cursorPadding = cursorMargin;

  ValueListenable<Rect> _cursorRect;
  ValueListenable<Rect> get cursorRect => _cursorRect;
  set cursorRect(ValueListenable<Rect> value) {
    if (_cursorRect == value) return;
    _cursorRect.removeListener(markNeedsLayout);
    _cursorRect = value;
    _cursorRect.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  EdgeInsets _padding;
  EdgeInsets get padding => _padding;
  set padding(EdgeInsets value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  EdgeInsets _cursorPadding;
  EdgeInsets get cursorMargin => _cursorPadding;
  set cursorMargin(EdgeInsets value) {
    if (_cursorPadding == value) return;
    _cursorPadding = value;
    markNeedsLayout();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    cursorRect.addListener(markNeedsLayout);
    super.attach(owner);
  }

  @override
  void detach() {
    cursorRect.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final child = this.child;

    if (child == null) {
      size = constraints.smallest;
      return;
    }

    size = constraints.biggest;

    final spaceAbove = cursorRect.value.top - padding.top - cursorMargin.top;

    final spaceBelow = size.height -
        cursorRect.value.bottom -
        padding.bottom -
        cursorMargin.bottom;

    final childConstraints = BoxConstraints(
      minWidth: 0,
      maxWidth: size.width - padding.horizontal,
      minHeight: 0,
      maxHeight: max(spaceAbove, spaceBelow),
    );

    child.layout(childConstraints, parentUsesSize: true);

    final fitsBelow = spaceBelow >= child.size.height;

    final childParentData = child.parentData as BoxParentData;
    childParentData.offset = Offset(
      min(size.width - padding.right - child.size.width, cursorRect.value.left),
      fitsBelow
          ? cursorRect.value.bottom + cursorMargin.bottom
          : cursorRect.value.top - cursorMargin.top - child.size.height,
    );
  }
}
