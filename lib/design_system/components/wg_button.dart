import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_keycap.dart';
import 'package:warpgate/design_system/components/wg_pressable.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

enum WgButtonVariant { primary, secondary, ghost, danger }

class WgButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = WgButtonVariant.secondary,
    this.icon,
    this.shortcut,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
  });

  const new primary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.shortcut,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
  }) : variant = WgButtonVariant.primary;

  const new ghost({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.shortcut,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
  }) : variant = WgButtonVariant.ghost;

  const new danger({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.shortcut,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
  }) : variant = WgButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final WgButtonVariant variant;
  final IconData? icon;
  final SingleActivator? shortcut;
  final bool loading;
  final bool expand;
  final bool autofocus;

  ({Color fill, Color ink, Color border}) _paint(
    BuildContext context,
    WgInteraction state,
  ) {
    final colors = context.colors;
    final lifted = state.highlighted;
    return switch (variant) {
      WgButtonVariant.primary => (
        fill: lifted ? colors.primaryFillHover : colors.primaryFill,
        ink: colors.onPrimaryFill,
        border: colors.transparent,
      ),
      WgButtonVariant.secondary => (
        fill: lifted ? colors.pressed : colors.raised,
        ink: colors.textPrimary,
        border: colors.hairlineStrong,
      ),
      WgButtonVariant.ghost => (
        fill: lifted ? colors.raised : colors.transparent,
        ink: colors.textPrimary,
        border: colors.transparent,
      ),
      WgButtonVariant.danger => (
        fill: lifted ? colors.negativeWash : colors.transparent,
        ink: colors.negative,
        border: colors.line(colors.negative),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final sizes = context.sizes;
    final enabled = onPressed != null && !loading;
    return WgPressable(
      semanticLabel: label,
      autofocus: autofocus,
      onPressed: enabled ? onPressed : null,
      builder: (context, state) {
        final active = _paint(context, state);
        final colors = context.colors;
        final paint = enabled || loading
            ? active
            : (
                fill: variant == WgButtonVariant.ghost
                    ? colors.transparent
                    : colors.raised,
                ink: colors.textMuted,
                border: variant == WgButtonVariant.ghost
                    ? colors.transparent
                    : colors.hairline,
              );
        final ink = paint.ink;
        return AnimatedContainer(
          duration: context.motion.fast,
          curve: context.motion.curve,
          constraints: BoxConstraints(minHeight: sizes.control),
          padding: EdgeInsets.symmetric(horizontal: space.md),
          decoration: BoxDecoration(
            color: paint.fill,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: paint.border),
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: ink, size: sizes.icon),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox.square(
                    dimension: sizes.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: sizes.stroke,
                      color: ink,
                    ),
                  )
                else if (icon != null)
                  Icon(icon),
                if (loading || icon != null) SizedBox(width: space.sm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(color: ink),
                  ),
                ),
                if (shortcut != null) ...[
                  SizedBox(width: space.sm),
                  WgKeycap(shortcut!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class WgIconButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.shortcut,
    this.selected = false,
    this.color,
    this.compact = false,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final SingleActivator? shortcut;
  final bool selected;
  final Color? color;
  final bool compact;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sizes = context.sizes;
    final extent = compact && !sizes.touch
        ? sizes.rowCompact - context.space.sm
        : sizes.control;
    return WgTooltip(
      message: label,
      shortcut: shortcut,
      child: WgPressable(
        semanticLabel: label,
        onPressed: onPressed,
        focusNode: focusNode,
        selected: selected,
        borderRadius: context.radii.smAll,
        builder: (context, state) {
          final ink = onPressed == null
              ? colors.disabledInk
              : color ??
                    (selected || state.highlighted
                        ? colors.textPrimary
                        : colors.textSecondary);
          return AnimatedContainer(
            duration: context.motion.fast,
            curve: context.motion.curve,
            width: extent,
            height: extent,
            decoration: BoxDecoration(
              color: selected
                  ? colors.pressed
                  : state.highlighted
                  ? colors.raised
                  : colors.transparent,
              borderRadius: context.radii.smAll,
            ),
            child: Icon(icon, size: sizes.icon, color: ink),
          );
        },
      ),
    );
  }
}

class WgTooltip extends StatelessWidget {
  const new({
    required this.message,
    required this.child,
    super.key,
    this.shortcut,
  });

  final String message;
  final SingleActivator? shortcut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      excludeFromSemantics: true,
      richMessage: WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: context.type.caption.copyWith(color: colors.textPrimary),
            ),
            if (shortcut != null) ...[
              SizedBox(width: context.space.sm),
              WgKeycap(shortcut!),
            ],
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.space.sm,
        vertical: context.space.xs,
      ),
      child: child,
    );
  }
}
