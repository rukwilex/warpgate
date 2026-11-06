import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/mouse/mode.dart';
import 'package:xterm/src/core/mouse/button.dart';
import 'package:xterm/src/core/mouse/button_state.dart';

abstract class MouseReporter {
  static String report(
    TerminalMouseButton button,
    TerminalMouseButtonState state,
    CellOffset position,
    MouseReportMode reportMode,
  ) {
    final x = position.x + 1;
    final y = position.y + 1;
    switch (reportMode) {
      case MouseReportMode.normal:
      case MouseReportMode.utf:
        final buttonID = state == TerminalMouseButtonState.up ? 3 : button.id;

        final btn = String.fromCharCode(32 + buttonID);

        final col = (reportMode == MouseReportMode.normal && x > 223) ||
                (reportMode == MouseReportMode.utf && x > 2015)
            ? '\x00'
            : String.fromCharCode(32 + x);
        final row = (reportMode == MouseReportMode.normal && y > 223) ||
                (reportMode == MouseReportMode.utf && y > 2015)
            ? '\x00'
            : String.fromCharCode(32 + y + 1);
        return "\x1b[M$btn$col$row";
      case MouseReportMode.sgr:
        final buttonID = button.id;
        final upDown = state == TerminalMouseButtonState.down ? 'M' : 'm';
        return "\x1b[<$buttonID;$x;$y$upDown";
      case MouseReportMode.urxvt:
        final buttonID =
            32 + (state == TerminalMouseButtonState.up ? 3 : button.id);
        return "\x1b[$buttonID;$x;${y}M";
    }
  }
}
