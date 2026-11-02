import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:warpgate/core/platform/platform_info.dart';

abstract final class ShortcutCodec {
  static String encode(SingleActivator activator) => [
    if (activator.control) 'ctrl',
    if (activator.alt) 'alt',
    if (activator.shift) 'shift',
    if (activator.meta) 'meta',
    activator.trigger.keyId.toString(),
  ].join('+');

  static SingleActivator? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('+');
    final keyId = int.tryParse(parts.last);
    if (keyId == null) return null;
    final key =
        LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
    return SingleActivator(
      key,
      control: parts.contains('ctrl'),
      alt: parts.contains('alt'),
      shift: parts.contains('shift'),
      meta: parts.contains('meta'),
    );
  }

  static SingleActivator primary(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) => PlatformInfo.isApple
      ? SingleActivator(key, meta: true, shift: shift, alt: alt)
      : SingleActivator(key, control: true, shift: true, alt: shift || alt);

  static SingleActivator plain(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) => PlatformInfo.isApple
      ? SingleActivator(key, meta: true, shift: shift, alt: alt)
      : SingleActivator(key, control: true, shift: shift, alt: alt);

  static bool matches(SingleActivator activator, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final logical = event.logicalKey;
    final sameKey =
        logical == activator.trigger ||
        (logical.synonyms.contains(activator.trigger));
    return sameKey &&
        keyboard.isControlPressed == activator.control &&
        keyboard.isAltPressed == activator.alt &&
        keyboard.isShiftPressed == activator.shift &&
        keyboard.isMetaPressed == activator.meta;
  }

  static SingleActivator? fromEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    final modifiers = {
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    };
    if (modifiers.contains(key)) return null;
    final keyboard = HardwareKeyboard.instance;
    return SingleActivator(
      key,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      meta: keyboard.isMetaPressed,
    );
  }
}
