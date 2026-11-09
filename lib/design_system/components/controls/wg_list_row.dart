import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_pressable.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

class WgListRow extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.leading,
    this.subtitle,
    this.trailing,
    this.meta,
    this.selected = false,
    this.onPressed,
    this.onSecondaryTapDown,
    this.onLongPress,
    this.onDoubleTap,
    this.semanticLabel,
    this.dense = false,
    this.focusNode,
    this.revealTrailing = false,
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final String? meta;
  final bool selected;
  final VoidCallback? onPressed;
  final GestureTapDownCallback? onSecondaryTapDown;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final String? semanticLabel;
  final bool dense;
  final FocusNode? focusNode;
  final bool revealTrailing;

  @override
  Widget build(BuildContext context) {
    if (!revealTrailing || trailing == null || context.sizes.touch) {
      return _row(context, trailingVisible: true);
    }
    return _RevealTrailing(
      builder: ({required visible}) => _row(context, trailingVisible: visible),
    );
  }

  Widget _row(BuildContext context, {required bool trailingVisible}) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    return WgPressable(
      semanticLabel: semanticLabel ?? [title, ?subtitle, ?meta].join(', '),
      onPressed: onPressed,
      focusNode: focusNode,
      onSecondaryTapDown: onSecondaryTapDown,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      selected: selected,
      borderRadius: context.radii.smAll,
      builder: (context, state) => AnimatedContainer(
        duration: context.motion.fast,
        curve: context.motion.curve,
        constraints: BoxConstraints(
          minHeight: dense ? sizes.rowCompact : sizes.row,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: space.sm,
          vertical: subtitle == null ? 0 : space.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.pressed
              : state.highlighted
              ? colors.raised
              : colors.transparent,
          borderRadius: context.radii.smAll,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (leading != null) ...[
                SizedBox(
                  width: sizes.icon,
                  child: Center(child: leading),
                ),
                SizedBox(width: space.sm),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.monoSmall.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (meta != null && constraints.maxWidth >= sizes.metaMinRow) ...[
                SizedBox(width: space.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (constraints.maxWidth * 0.4).clamp(
                      0,
                      sizes.sidebar,
                    ),
                  ),
                  child: Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.type.monoSmall.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                SizedBox(width: space.sm),
                AnimatedOpacity(
                  opacity: trailingVisible ? 1 : 0,
                  duration: context.motion.fast,
                  child: IgnorePointer(
                    ignoring: !trailingVisible,
                    child: trailing,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealTrailing extends StatefulWidget {
  const new({required this.builder});

  final Widget Function({required bool visible}) builder;

  @override
  State<_RevealTrailing> createState() => _RevealTrailingState();
}

class _RevealTrailingState extends State<_RevealTrailing> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _focused = value),
      child: widget.builder(visible: _hovered || _focused),
    ),
  );
}
