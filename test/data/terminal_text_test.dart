import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('tail skips the blank rows under the prompt', () {
    final terminal = Terminal()
      ..resize(40, 24)
      ..write('one\r\ntwo\r\nthree\r\n\$ ');
    expect(TerminalText.tail(terminal, 2), 'three\n\$');
    expect(TerminalText.tail(terminal, 10), 'one\ntwo\nthree\n\$');
  });
}
