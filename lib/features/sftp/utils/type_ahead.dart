import 'package:flutter/services.dart';

bool isTypeAheadKey(KeyEvent event) {
  final character = event.character;
  if (character == null || character.isEmpty) return false;
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isMetaPressed ||
      keyboard.isControlPressed ||
      keyboard.isAltPressed) {
    return false;
  }
  final code = character.codeUnitAt(0);
  return code > 32 && code != 127;
}
