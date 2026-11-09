import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/core/shortcuts/shortcut_codec.dart';
import 'package:warpgate/design_system/design_system.dart';

class SettingsShortcutRecordDialog extends StatefulWidget {
  const new({required this.title, super.key});

  final String title;

  @override
  State<SettingsShortcutRecordDialog> createState() =>
      _SettingsShortcutRecordDialogState();
}

class _SettingsShortcutRecordDialogState
    extends State<SettingsShortcutRecordDialog> {
  SingleActivator? _captured;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WgDialog(
    title: 'Shortcut for ${widget.title}',
    actions: [
      WgButton.ghost(
        label: 'Remove shortcut',
        onPressed: () => Navigator.of(context).pop(''),
      ),
      WgButton.ghost(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      WgButton.primary(
        label: 'Save',
        onPressed: _captured == null
            ? null
            : () => Navigator.of(context).pop(ShortcutCodec.encode(_captured!)),
      ),
    ],
    child: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        final activator = ShortcutCodec.fromEvent(event);
        if (activator == null) return KeyEventResult.ignored;
        if (activator.trigger == LogicalKeyboardKey.escape &&
            !activator.control &&
            !activator.meta) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        setState(() => _captured = activator);
        return KeyEventResult.handled;
      },
      child: Container(
        height: context.sizes.keyRecorder,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.canvasDeep,
          borderRadius: context.radii.mdAll,
          border: Border.all(color: context.colors.focusRing),
        ),
        child: _captured == null
            ? Text(
                'Press the keys',
                style: context.type.body.copyWith(
                  color: context.colors.textMuted,
                ),
              )
            : WgKeycap(_captured!),
      ),
    ),
  );
}
