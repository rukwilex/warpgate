import 'package:flutter/widgets.dart';

class CustomKeyboardListener extends StatelessWidget {
  final Widget child;

  final FocusNode focusNode;

  final bool autofocus;

  final void Function(String) onInsert;

  final void Function(String?) onComposing;

  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  const CustomKeyboardListener({
    super.key,
    required this.child,
    required this.focusNode,
    this.autofocus = false,
    required this.onInsert,
    required this.onComposing,
    required this.onKeyEvent,
  });

  KeyEventResult _onKeyEvent(FocusNode focusNode, KeyEvent keyEvent) {
    final handled = onKeyEvent(focusNode, keyEvent);
    if (handled == KeyEventResult.ignored) {
      if (keyEvent.character != null && keyEvent.character != "") {
        onInsert(keyEvent.character!);
        return KeyEventResult.handled;
      }
    }
    return handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: _onKeyEvent,
      child: child,
    );
  }
}
