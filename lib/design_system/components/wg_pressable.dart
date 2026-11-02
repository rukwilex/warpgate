import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

typedef WgPressableBuilder = Widget Function(
  BuildContext context,
  WgInteraction interaction,
);

@immutable
class WgInteraction {
  const new({
    required this.hovered,
    required this.focused,
    required this.pressed,
    required this.enabled,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;
  final bool enabled;

  bool get highlighted => enabled && (hovered || pressed);
}

class WgPressable extends StatefulWidget {
  const new({
    required this.builder,
    required this.semanticLabel,
    super.key,
    this.onPressed,
    this.onSecondaryTapDown,
    this.onLongPress,
    this.onDoubleTap,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.selected,
    this.toggled,
    this.isButton = true,
    this.mouseCursor,
  });

  final WgPressableBuilder builder;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final GestureTapDownCallback? onSecondaryTapDown;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final bool? selected;
  final bool? toggled;
  final bool isButton;
  final MouseCursor? mouseCursor;

  @override
  State<WgPressable> createState() => _WgPressableState();
}

class _WgPressableState extends State<WgPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = widget.borderRadius ?? context.radii.mdAll;
    final interaction = WgInteraction(
      hovered: _hovered,
      focused: _focused,
      pressed: _pressed,
      enabled: _enabled,
    );
    final ringWidth = context.sizes.focusRing;
    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled
            ? (widget.mouseCursor ?? SystemMouseCursors.click)
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onDoubleTap: widget.onDoubleTap,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: () => _setPressed(false),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _focused ? colors.focusRing : colors.transparent,
                width: ringWidth,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: widget.builder(context, interaction),
          ),
        ),
      ),
    );
  }
}
