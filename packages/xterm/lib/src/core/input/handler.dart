import 'package:xterm/src/core/input/keys.dart';
import 'package:xterm/src/core/input/keytab/keytab.dart';
import 'package:xterm/src/core/state.dart';
import 'package:xterm/src/core/platform.dart';

class TerminalKeyboardEvent {
  final TerminalKey key;

  final bool shift;

  final bool ctrl;

  final bool alt;

  final TerminalState state;

  final bool altBuffer;

  final TerminalTargetPlatform platform;

  TerminalKeyboardEvent({
    required this.key,
    required this.shift,
    required this.ctrl,
    required this.alt,
    required this.state,
    required this.altBuffer,
    required this.platform,
  });

  TerminalKeyboardEvent copyWith({
    TerminalKey? key,
    bool? shift,
    bool? ctrl,
    bool? alt,
    TerminalState? state,
    bool? altBuffer,
    TerminalTargetPlatform? platform,
  }) {
    return TerminalKeyboardEvent(
      key: key ?? this.key,
      shift: shift ?? this.shift,
      ctrl: ctrl ?? this.ctrl,
      alt: alt ?? this.alt,
      state: state ?? this.state,
      altBuffer: altBuffer ?? this.altBuffer,
      platform: platform ?? this.platform,
    );
  }
}

abstract class TerminalInputHandler {
  String? call(TerminalKeyboardEvent event);
}

class CascadeInputHandler implements TerminalInputHandler {
  final List<TerminalInputHandler> _handlers;

  const CascadeInputHandler(this._handlers);

  @override
  String? call(TerminalKeyboardEvent event) {
    for (var handler in _handlers) {
      final result = handler(event);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

const defaultInputHandler = CascadeInputHandler([
  KeytabInputHandler(),
  CtrlInputHandler(),
  AltInputHandler(),
]);

class KeytabInputHandler implements TerminalInputHandler {
  const KeytabInputHandler([this.keytab]);

  final Keytab? keytab;

  @override
  String? call(TerminalKeyboardEvent event) {
    final keytab = this.keytab ?? Keytab.defaultKeytab;

    final record = keytab.find(
      event.key,
      ctrl: event.ctrl,
      alt: event.alt,
      shift: event.shift,
      newLineMode: event.state.lineFeedMode,
      appCursorKeys: event.state.appKeypadMode,
      appKeyPad: event.state.appKeypadMode,
      appScreen: event.altBuffer,
      macos: event.platform == TerminalTargetPlatform.macos,
    );

    if (record == null) {
      return null;
    }

    var result = record.action.unescapedValue();
    result = insertModifiers(event, result);
    return result;
  }

  String insertModifiers(TerminalKeyboardEvent event, String action) {
    String? code;

    if (event.shift && event.alt && event.ctrl) {
      code = '8';
    } else if (event.ctrl && event.alt) {
      code = '7';
    } else if (event.shift && event.ctrl) {
      code = '6';
    } else if (event.ctrl) {
      code = '5';
    } else if (event.shift && event.alt) {
      code = '4';
    } else if (event.alt) {
      code = '3';
    } else if (event.shift) {
      code = '2';
    }

    if (code != null) {
      return action.replaceAll('*', code);
    }

    return action;
  }
}

class CtrlInputHandler implements TerminalInputHandler {
  const CtrlInputHandler();

  @override
  String? call(TerminalKeyboardEvent event) {
    if (!event.ctrl || event.shift || event.alt) {
      return null;
    }

    final key = event.key;

    if (key.index >= TerminalKey.keyA.index &&
        key.index <= TerminalKey.keyZ.index) {
      final input = key.index - TerminalKey.keyA.index + 1;
      return String.fromCharCode(input);
    }

    return null;
  }
}

class AltInputHandler implements TerminalInputHandler {
  const AltInputHandler();

  @override
  String? call(TerminalKeyboardEvent event) {
    if (!event.alt || event.ctrl || event.shift) {
      return null;
    }

    if (event.platform == TerminalTargetPlatform.macos) {
      return null;
    }

    final key = event.key;

    if (key.index >= TerminalKey.keyA.index &&
        key.index <= TerminalKey.keyZ.index) {
      final charCode = key.index - TerminalKey.keyA.index + 65;
      final input = [0x1b, charCode];
      return String.fromCharCodes(input);
    }

    return null;
  }
}
