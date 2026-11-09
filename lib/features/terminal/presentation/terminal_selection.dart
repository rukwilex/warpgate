import 'dart:async';

import 'package:flutter/services.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:xterm/xterm.dart';

class TerminalSelection {
  new(this.controller, {required this.session});

  final TerminalController controller;
  final TerminalSession? Function() session;
  String? _last;

  String? text() {
    final selection = controller.selection;
    final current = session();
    if (selection == null || current == null) return null;
    return current.terminal.buffer.getText(selection);
  }

  void copyIfChanged() {
    final selected = text();
    if (selected != null && selected.isNotEmpty && selected != _last) {
      _last = selected;
      unawaited(Clipboard.setData(ClipboardData(text: selected)));
    }
  }

  Future<void> copy() async {
    final selected = text();
    if (selected == null || selected.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: selected));
    controller.clearSelection();
  }
}
