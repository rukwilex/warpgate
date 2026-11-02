import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  String? initial,
  String? helper,
  bool mono = false,
  int maxLines = 1,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    label: label,
    confirm: confirm,
    initial: initial,
    helper: helper,
    mono: mono,
    maxLines: maxLines,
  ),
);

class _TextPrompt extends StatefulWidget {
  const new({
    required this.title,
    required this.label,
    required this.confirm,
    required this.mono,
    required this.maxLines,
    this.initial,
    this.helper,
  });

  final String title;
  final String label;
  final String confirm;
  final String? initial;
  final String? helper;
  final bool mono;
  final int maxLines;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial?.length ?? 0,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => WgDialog(
    title: widget.title,
    actions: [
      WgButton.ghost(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => WgButton.primary(
          label: widget.confirm,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ),
    ],
    child: WgTextField(
      controller: _controller,
      label: widget.label,
      helper: widget.helper,
      autofocus: true,
      mono: widget.mono,
      maxLines: widget.maxLines,
      onSubmitted: (_) => _submit(),
    ),
  );
}
