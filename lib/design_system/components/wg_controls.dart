import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/components/wg_button.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
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
                        color: selected
                            ? colors.textPrimary
                            : colors.textPrimary,
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
              if (meta != null) ...[
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

class WgSectionLabel extends StatelessWidget {
  const new(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(space.sm, space.xxl, space.xs, space.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: context.type.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class WgTextField extends StatefulWidget {
  const new({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.helper,
    this.error,
    this.obscure = false,
    this.mono = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.leadingIcon,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
    this.textInputAction,
    this.enabled = true,
    this.autofillHints,
    this.trailing,
  });

  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? helper;
  final String? error;
  final bool obscure;
  final bool mono;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? leadingIcon;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final Widget? trailing;

  @override
  State<WgTextField> createState() => _WgTextFieldState();
}

class _WgTextFieldState extends State<WgTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final sizes = context.sizes;
    final textStyle = widget.mono ? context.type.mono : context.type.body;
    OutlineInputBorder border(Color color, [double? width]) =>
        OutlineInputBorder(
          borderRadius: context.radii.mdAll,
          borderSide: BorderSide(color: color, width: width ?? sizes.hairline),
        );
    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: _hidden,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      minLines: widget.minLines,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: !widget.obscure && !widget.mono,
      style: textStyle,
      cursorColor: colors.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.raised,
        hintText: widget.placeholder,
        hintStyle: textStyle.copyWith(color: colors.textMuted),
        constraints: BoxConstraints(minHeight: sizes.control),
        contentPadding: EdgeInsets.symmetric(
          horizontal: space.md,
          vertical: space.sm,
        ),
        prefixIcon: widget.leadingIcon == null
            ? null
            : Icon(
                widget.leadingIcon,
                size: sizes.icon,
                color: colors.textMuted,
              ),
        prefixIconConstraints: BoxConstraints(
          minWidth: sizes.control,
          minHeight: sizes.icon,
        ),
        suffixIcon: widget.obscure
            ? Padding(
                padding: EdgeInsets.only(right: space.xs),
                child: WgIconButton(
                  icon: _hidden ? WgIcons.eye : WgIcons.eyeOff,
                  label: _hidden ? 'Show' : 'Hide',
                  compact: true,
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              )
            : widget.trailing,
        suffixIconConstraints: BoxConstraints(
          minWidth: sizes.control,
          minHeight: sizes.rowCompact - space.sm,
        ),
        border: border(colors.hairline),
        enabledBorder: border(colors.hairline),
        disabledBorder: border(colors.hairline),
        focusedBorder: border(colors.focusRing, sizes.focusRing / 1.5),
        errorBorder: border(colors.negative),
        focusedErrorBorder: border(colors.negative, sizes.focusRing / 1.5),
        errorText: widget.error,
        errorStyle: context.type.caption.copyWith(color: colors.negative),
        helperText: widget.helper,
        helperMaxLines: 3,
        errorMaxLines: 3,
        helperStyle: context.type.caption.copyWith(color: colors.textMuted),
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label!,
          style: context.type.label.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: space.xs),
        field,
      ],
    );
  }
}

class WgSwitch extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: label,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: colors.onAccent,
        activeTrackColor: colors.accent,
        inactiveThumbColor: colors.textSecondary,
        inactiveTrackColor: colors.raised,
        trackOutlineColor: WidgetStatePropertyAll(colors.hairlineStrong),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class WgCheckbox extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: label,
      child: Checkbox(
        value: value,
        onChanged: onChanged == null ? null : (next) => onChanged!(next!),
        activeColor: colors.accent,
        checkColor: colors.onAccent,
        side: BorderSide(
          color: colors.hairlineStrong,
          width: context.sizes.stroke,
        ),
        shape: RoundedRectangleBorder(borderRadius: context.radii.xsAll),
      ),
    );
  }
}

class WgSegment<T> {
  const new(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class WgSegmented<T> extends StatelessWidget {
  const new({
    required this.segments,
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
    this.iconsOnly = false,
  });

  final List<WgSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;
  final bool iconsOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final inner = context.radii.md - space.hair;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: Semantics(
        label: label,
        container: true,
        child: Container(
          padding: EdgeInsets.all(space.hair),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final segment in segments)
                WgPressable(
                  semanticLabel: segment.label,
                  selected: segment.value == value,
                  borderRadius: BorderRadius.circular(inner),
                  onPressed: () => onChanged(segment.value),
                  builder: (context, state) {
                    final active = segment.value == value;
                    final ink = active
                        ? colors.textPrimary
                        : colors.textSecondary;
                    return AnimatedContainer(
                      duration: context.motion.fast,
                      curve: context.motion.curve,
                      constraints: BoxConstraints(
                        minHeight: context.sizes.control - space.xs,
                        minWidth: context.sizes.control - space.xs,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: iconsOnly ? space.xs : space.md,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? colors.surface
                            : state.highlighted
                            ? colors.pressed
                            : colors.transparent,
                        borderRadius: BorderRadius.circular(inner),
                        border: Border.all(
                          color: active
                              ? colors.hairlineStrong
                              : colors.transparent,
                        ),
                      ),
                      child: iconsOnly && segment.icon != null
                          ? Tooltip(
                              message: segment.label,
                              excludeFromSemantics: true,
                              child: Icon(
                                segment.icon,
                                size: context.sizes.icon,
                                color: ink,
                              ),
                            )
                          : Text(
                              segment.label,
                              style: context.type.label.copyWith(color: ink),
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WgTag extends StatelessWidget {
  const new(this.text, {super.key, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = tone ?? colors.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.xs + context.space.hair,
        vertical: context.sizes.hairline,
      ),
      decoration: BoxDecoration(
        borderRadius: context.radii.xsAll,
        border: Border.all(
          color: tone == null ? colors.hairlineStrong : colors.line(tone!),
        ),
      ),
      child: Text(text, style: context.type.monoSmall.copyWith(color: ink)),
    );
  }
}

class WgCheckRow extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: context.radii.smAll,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(
          children: [
            WgCheckbox(value: value, onChanged: onChanged, label: label),
            Expanded(child: Text(label, style: context.type.body)),
          ],
        ),
      ),
    );
  }
}
