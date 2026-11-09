import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/presentation/terminal_surface.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_status_overlay.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:xterm/xterm.dart';

class TerminalViewport extends StatelessWidget {
  const new({
    required this.session,
    required this.status,
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.theme,
    required this.cursorType,
    required this.fontSize,
    required this.onFontSize,
    required this.onKeyEvent,
    required this.onFocusPane,
    required this.onMenu,
    required this.bell,
    super.key,
  });

  final TerminalSession session;
  final LinkStatus status;
  final String title;
  final TerminalController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final TerminalTheme theme;
  final TerminalCursorType cursorType;
  final double fontSize;
  final ValueChanged<double> onFontSize;
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onFocusPane;
  final ValueChanged<Offset> onMenu;
  final bool bell;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Semantics(
        label: 'Terminal, $title, ${status.state.dot.label.toLowerCase()}',
        textField: true,
        child: TerminalSurface(
          session: session,
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          theme: theme,
          cursorType: cursorType,
          fontSize: fontSize,
          onFontSize: onFontSize,
          onKeyEvent: onKeyEvent,
          onTapUp: (_, _) => onFocusPane(),
          onSecondaryTapDown: (details, _) => onMenu(details.globalPosition),
        ),
      ),
      if (bell)
        IgnorePointer(
          child: ColoredBox(color: context.colors.accentWash),
        ),
      if (status.state != LinkState.connected &&
          status.state != LinkState.busy)
        TerminalStatusOverlay(
          status: status,
          session: session,
          title: title,
        ),
    ],
  );
}
