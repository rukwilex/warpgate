import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/components/wg_button.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

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
