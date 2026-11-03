import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

Future<void> showFilePreview(
  BuildContext context,
  FileEndpoint endpoint,
  FileEntry entry,
) => showDialog<void>(
  context: context,
  builder: (_) => _PreviewDialog(endpoint: endpoint, entry: entry),
);

Future<bool> showFileEditor(
  BuildContext context,
  FileEndpoint endpoint,
  FileEntry entry,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditorDialog(endpoint: endpoint, entry: entry),
    ) ??
    false;

Future<int?> showPermissionsDialog(BuildContext context, FileEntry entry) =>
    showDialog<int>(
      context: context,
      builder: (_) => _PermissionsDialog(entry: entry),
    );

Future<void> showProperties(
  BuildContext context,
  FileEndpoint endpoint,
  FileEntry entry,
) => showDialog<void>(
  context: context,
  builder: (context) => WgDialog(
    title: entry.name,
    actions: [
      WgButton.ghost(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in [
          ('Location', endpoint.label),
          ('Path', entry.path),
          (
            'Kind',
            entry.isDirectory
                ? 'Folder'
                : entry.isLink
                ? 'Link'
                : 'File',
          ),
          if (!entry.isDirectory)
            ('Size', '${Format.bytes(entry.size)} (${entry.size} bytes)'),
          if (entry.modified != null)
            ('Modified', Format.time(entry.modified!)),
          if (entry.mode != null)
            (
              'Permissions',
              '${Format.mode(entry.mode!)}  ${Format.octal(entry.mode!)}',
            ),
        ])
          Padding(
            padding: EdgeInsets.only(bottom: context.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.type.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                SelectableText(value, style: context.type.mono),
              ],
            ),
          ),
      ],
    ),
  ),
);

class _PreviewDialog extends StatefulWidget {
  const new({required this.endpoint, required this.entry});

  final FileEndpoint endpoint;
  final FileEntry entry;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late final Future<Uint8List> _bytes = widget.endpoint.readAll(
    widget.entry.path,
    maxBytes: widget.entry.looksLikeImage ? 16 * 1024 * 1024 : 1024 * 1024,
  );

  @override
  Widget build(BuildContext context) => WgDialog(
    title: widget.entry.name,
    wide: true,
    scrollable: false,
    actions: [
      WgButton.ghost(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return WgInlineMessage(
              tone: WgTone.negative,
              title: 'Preview is not available',
              message: snapshot.error.toString(),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const WgSkeletonList(rows: 8, label: 'Loading preview');
          }
          if (widget.entry.looksLikeImage) {
            return Semantics(
              image: true,
              label: widget.entry.name,
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            );
          }
          final text = utf8.decode(bytes, allowMalformed: true);
          if (text.contains('\u0000')) {
            return const WgInlineMessage(
              message: 'This looks like a binary file, so there is nothing to show as text.',
            );
          }
          return Container(
            decoration: BoxDecoration(
              color: context.colors.canvasDeep,
              borderRadius: context.radii.mdAll,
              border: Border.all(color: context.colors.hairline),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.space.md),
              child: SelectableText(text, style: context.type.mono),
            ),
          );
        },
      ),
    ),
  );
}

class _EditorDialog extends StatefulWidget {
  const new({required this.endpoint, required this.entry});

  final FileEndpoint endpoint;
  final FileEntry entry;

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
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
              const WgSkeletonList(rows: 10, label: 'Loading file')
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: WgTextField(
                  controller: _controller,
                  mono: true,
                  maxLines: null,
                  minLines: 16,
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

class _PermissionsDialog extends StatefulWidget {
  const new({required this.entry});

  final FileEntry entry;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late int _mode = (widget.entry.mode ?? 0x1A4) & 0x1FF;
  late final _octal = TextEditingController(text: Format.octal(_mode));

  @override
  void dispose() {
    _octal.dispose();
    super.dispose();
  }

  void _setBit(int bit, {required bool on}) {
    setState(() {
      _mode = on ? _mode | (1 << bit) : _mode & ~(1 << bit);
      _octal.text = Format.octal(_mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    const who = ['Owner', 'Group', 'Others'];
    const what = ['Read', 'Write', 'Run'];
    return WgDialog(
      title: 'Permissions for ${widget.entry.name}',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Apply',
          onPressed: () => Navigator.of(context).pop(_mode),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final label in what)
                    Center(child: Text(label, style: context.type.caption)),
                ],
              ),
              for (final (row, label) in who.indexed)
                TableRow(
                  children: [
                    Text(label, style: context.type.body),
                    for (var column = 0; column < 3; column++)
                      Center(
                        child: WgCheckbox(
                          label: '$label ${what[column].toLowerCase()}',
                          value: _mode & (1 << (8 - row * 3 - column)) != 0,
                          onChanged: (value) =>
                              _setBit(8 - row * 3 - column, on: value),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          SizedBox(height: context.space.lg),
          WgTextField(
            controller: _octal,
            label: 'Octal',
            mono: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-7]')),
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (value) {
              final parsed = int.tryParse(value, radix: 8);
              if (parsed != null && value.length == 3) {
                setState(() => _mode = parsed);
              }
            },
          ),
          SizedBox(height: context.space.sm),
          Text(
            Format.mode(_mode),
            style: context.type.mono.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
