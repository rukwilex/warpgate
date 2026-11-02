import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

abstract final class WgShortcutLabel {
  static bool get usesCommandKey =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static List<String> keys(SingleActivator activator) {
    final names = usesCommandKey ? _macNames : _pcNames;
    return [
      if (activator.control) names.control,
      if (activator.alt) names.alt,
      if (activator.shift) names.shift,
      if (activator.meta) names.meta,
      _trigger(activator.trigger),
    ];
  }

  static const ({String alt, String control, String meta, String shift})
  _macNames = (control: '⌃', alt: '⌥', shift: '⇧', meta: '⌘');
  static const ({String alt, String control, String meta, String shift})
  _pcNames = (control: 'Ctrl', alt: 'Alt', shift: 'Shift', meta: 'Win');
  static const ({String alt, String control, String meta, String shift})
  _macSpoken = (
    control: 'Control',
    alt: 'Option',
    shift: 'Shift',
    meta: 'Command',
  );
  static const ({String alt, String control, String meta, String shift})
  _pcSpoken = (control: 'Control', alt: 'Alt', shift: 'Shift', meta: 'Windows');

  static String spoken(SingleActivator activator) {
    final names = usesCommandKey ? _macSpoken : _pcSpoken;
    return [
      if (activator.control) names.control,
      if (activator.alt) names.alt,
      if (activator.shift) names.shift,
      if (activator.meta) names.meta,
      activator.trigger.keyLabel,
    ].join(' ');
  }

  static String _trigger(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.arrowUp => '↑',
    LogicalKeyboardKey.arrowDown => '↓',
    LogicalKeyboardKey.arrowLeft => '←',
    LogicalKeyboardKey.arrowRight => '→',
    LogicalKeyboardKey.enter => usesCommandKey ? '↩' : 'Enter',
    LogicalKeyboardKey.escape => 'Esc',
    LogicalKeyboardKey.backspace => '⌫',
    LogicalKeyboardKey.tab => 'Tab',
    LogicalKeyboardKey.space => 'Space',
    LogicalKeyboardKey.backslash => r'\',
    LogicalKeyboardKey.minus => '-',
    LogicalKeyboardKey.equal => '=',
    LogicalKeyboardKey.bracketLeft => '[',
    LogicalKeyboardKey.bracketRight => ']',
    LogicalKeyboardKey.comma => ',',
    LogicalKeyboardKey.period => '.',
    LogicalKeyboardKey.slash => '/',
    _ => key.keyLabel.toUpperCase(),
  };
}

class WgKeycap extends StatelessWidget {
  const new(this.activator, {super.key});

  final SingleActivator activator;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final keys = WgShortcutLabel.keys(activator);
    return Semantics(
      label: WgShortcutLabel.spoken(activator),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, key) in keys.indexed) ...[
            if (index > 0) SizedBox(width: space.hair),
            Container(
              constraints: BoxConstraints(
                minWidth: context.sizes.keycap,
                minHeight: context.sizes.keycap,
                maxHeight: context.sizes.keycap,
              ),
              padding: EdgeInsets.symmetric(horizontal: space.xs),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: context.radii.xsAll,
                border: Border.all(color: colors.hairlineStrong),
              ),
              child: Text(key, style: context.type.keycap),
            ),
          ],
        ],
      ),
    );
  }
}
