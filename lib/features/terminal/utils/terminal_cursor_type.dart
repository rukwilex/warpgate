import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:xterm/xterm.dart';

TerminalCursorType terminalCursorType(CursorShape shape) => switch (shape) {
  CursorShape.block => TerminalCursorType.block,
  CursorShape.underline => TerminalCursorType.underline,
  CursorShape.bar => TerminalCursorType.verticalBar,
};
