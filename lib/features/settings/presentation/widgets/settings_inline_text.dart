import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';

class SettingsInlineText extends StatefulWidget {
  const new({
    required this.initial,
    required this.onSubmitted,
    required this.label,
    super.key,
    this.digits = false,
  });

  final String initial;
  final String label;
  final ValueChanged<String> onSubmitted;
  final bool digits;

  @override
  State<SettingsInlineText> createState() => _SettingsInlineTextState();
}

class _SettingsInlineTextState extends State<SettingsInlineText> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmitted(_controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.digits ? context.sizes.fieldShort : context.sizes.sidebar,
    child: Semantics(
      label: widget.label,
      child: WgTextField(
        controller: _controller,
        focusNode: _focus,
        mono: true,
        keyboardType: widget.digits ? TextInputType.number : null,
        inputFormatters: widget.digits
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        onSubmitted: (value) => widget.onSubmitted(value.trim()),
      ),
    ),
  );
}
