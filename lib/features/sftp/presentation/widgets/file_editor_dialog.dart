import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/presentation/file_browser_constants.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FileEditorDialog extends StatefulWidget {
  const new({required this.endpoint, required this.entry, super.key});

  final FileEndpoint endpoint;
  final FileEntry entry;

  @override
  State<FileEditorDialog> createState() => _FileEditorDialogState();
}

class _FileEditorDialogState extends State<FileEditorDialog> {
  final _controller = TextEditingController();
  String? _original;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.endpoint.readAll(widget.entry.path);
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;
      setState(() {
        _original = text;
        _controller.text = text;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _original != null && _controller.text != _original;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.endpoint.writeAll(
        widget.entry.path,
        Uint8List.fromList(utf8.encode(_controller.text)),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $error';
        });
      }
    }
  }

  Future<void> _close() async {
    if (_dirty) {
      final discard = await showWgConfirm(
        context,
        title: 'Discard changes to ${widget.entry.name}?',
        message: 'Your edits have not been saved to ${widget.endpoint.label}.',
        confirmLabel: 'Discard changes',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!discard) return;
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final save = SingleActivator(
      LogicalKeyboardKey.keyS,
      meta: WgShortcutLabel.usesCommandKey,
      control: !WgShortcutLabel.usesCommandKey,
    );
    return CallbackShortcuts(
      bindings: {save: () => unawaited(_save())},
      child: WgDialog(
        title: widget.entry.name,
        wide: true,
        scrollable: false,
        actions: [
          WgButton.ghost(label: 'Close', onPressed: () => unawaited(_close())),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => WgButton.primary(
              label: 'Save',
              shortcut: save,
              loading: _saving,
              onPressed: _dirty ? () => unawaited(_save()) : null,
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.endpoint.label} · ${widget.entry.path}',
              style: context.type.monoSmall.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            SizedBox(height: context.space.sm),
            if (_error != null) ...[
              WgInlineMessage(tone: WgTone.negative, message: _error!),
              SizedBox(height: context.space.sm),
            ],
            if (_original == null && _error == null)
              const WgSkeletonList(
                rows: FileBrowserConstants.editorSkeletonRows,
                label: 'Loading file',
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(context).height *
                      FileBrowserConstants.dialogHeightFactor,
                ),
                child: WgTextField(
                  controller: _controller,
                  mono: true,
                  maxLines: null,
                  minLines: FileBrowserConstants.editorMinLines,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
