import 'package:fake_async/fake_async.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/features/terminal/domain/terminal_geometry.dart';
import 'package:warpgate/features/terminal/domain/terminal_reflow.dart';
import 'package:xterm/xterm.dart';

Terminal terminalWith(String text, {int width = 10, int height = 5}) {
  return Terminal()
    ..resize(width, height)
    ..write(text);
}

List<BufferLine> linesOf(Terminal terminal) {
  final lines = terminal.mainBuffer.lines;
  return [for (var i = 0; i < lines.length; i++) lines[i]];
}

ReflowResult reflowTo(Terminal terminal, int width, {int height = 5}) {
  final buffer = terminal.mainBuffer;
  return TerminalReflow.reflow(
    lines: linesOf(terminal),
    oldWidth: terminal.viewWidth,
    newWidth: width,
    newHeight: height,
    cursorX: buffer.cursorX,
    cursorRow: buffer.absoluteCursorY,
  );
}

List<String> rows(ReflowResult result) => [
  for (final line in result.lines) line.getText().replaceAll('\u0000', ''),
];

List<String> logical(ReflowResult result) {
  final out = <String>[];
  for (final line in result.lines) {
    final text = line.getText();
    if (line.isWrapped && out.isNotEmpty) {
      out[out.length - 1] += text;
    } else {
      out.add(text);
    }
  }
  return [for (final line in out) line.trimRight()];
}

void main() {
  group('reflow', () {
    test('wrapped lines join and rewrap to a wider width', () {
      final terminal = terminalWith('a' * 30);
      final result = reflowTo(terminal, 20);
      expect(rows(result).take(2), ['a' * 20, 'a' * 10]);
      expect(result.lines[1].isWrapped, isTrue);
      expect(logical(result).first, 'a' * 30);
    });

    test('wrapped lines rewrap to a narrower width', () {
      final terminal = terminalWith(
        'abcdefghij'
        'klmno',
      );
      final result = reflowTo(terminal, 4);
      expect(rows(result).take(4), ['abcd', 'efgh', 'ijkl', 'mno']);
      expect(logical(result).first, 'abcdefghijklmno');
    });

    test('hard line breaks stay', () {
      final terminal = terminalWith('abc\r\ndef\r\n');
      final result = reflowTo(terminal, 2);
      expect(rows(result).take(4), ['ab', 'c', 'de', 'f']);
      expect(result.lines[1].isWrapped, isTrue);
      expect(result.lines[2].isWrapped, isFalse);
      expect(logical(result).take(2), ['abc', 'def']);
    });

    test('a space at the wrap point survives joining', () {
      final terminal = terminalWith('hello world');
      expect(terminal.mainBuffer.lines[0].getText(), startsWith('hello worl'));
      final narrow = reflowTo(terminal, 6);
      expect(rows(narrow).take(2), ['hello ', 'world']);
      final wide = TerminalReflow.reflow(
        lines: narrow.lines,
        oldWidth: 6,
        newWidth: 20,
        newHeight: 5,
        cursorX: narrow.cursorX,
        cursorRow: narrow.cursorRow,
      );
      expect(rows(wide).first, 'hello world');
    });

    test('trailing spaces on the last row are kept', () {
      final terminal = terminalWith(r'$ ');
      final result = reflowTo(terminal, 20);
      expect(result.lines.first.getText().startsWith(r'$ '), isTrue);
      expect(result.cursorX, 2);
      expect(result.cursorRow, 0);
    });

    test('CJK characters never split across rows', () {
      final terminal = terminalWith('你好世界', width: 5);
      expect(terminal.mainBuffer.lines[1].isWrapped, isTrue);
      final wide = reflowTo(terminal, 8);
      expect(rows(wide).first, '你好世界');
      final narrow = reflowTo(terminal, 3);
      expect(rows(narrow).take(4), ['你', '好', '世', '界']);
      for (final line in narrow.lines.take(4)) {
        expect(line.getWidth(0), 2);
      }
    });

    test('emoji keep their width', () {
      final terminal = terminalWith('ab😀cd', width: 3);
      final result = reflowTo(terminal, 10);
      expect(rows(result).first, 'ab😀cd');
      expect(result.lines.first.getWidth(2), 2);
    });

    test('cursor follows its character after reflow', () {
      final terminal = terminalWith('0123456789abcdef');
      expect(terminal.mainBuffer.absoluteCursorY, 1);
      expect(terminal.mainBuffer.cursorX, 6);
      final wide = reflowTo(terminal, 20);
      expect(wide.cursorRow, 0);
      expect(wide.cursorX, 16);
      final narrow = reflowTo(terminal, 4);
      expect(narrow.cursorRow, 4);
      expect(narrow.cursorX, 0);
    });

    test('cursor on a prompt below output stays on that prompt', () {
      final terminal = terminalWith('first line\r\nsecond\r\n\$ ');
      final result = reflowTo(terminal, 5);
      final row = result.lines[result.cursorRow].getText();
      expect(row.startsWith(r'$ '), isTrue);
      expect(result.cursorX, 2);
    });

    test('screen keeps at least the requested height', () {
      final terminal = terminalWith('x');
      final result = reflowTo(terminal, 20, height: 7);
      expect(result.lines.length, 7);
      expect(result.cursorScreenY, 0);
      expect(result.lines.every((line) => line.length == 20), isTrue);
    });

    test('row map points old rows at their new rows', () {
      final terminal = terminalWith('${'a' * 10}${'b' * 10}\r\nc');
      final result = reflowTo(terminal, 20);
      expect(result.rowMap[0], 0);
      expect(result.rowMap[1], 0);
      expect(result.rowMap[2], 1);
    });

    test('scrollback is capped at max lines', () {
      final terminal = terminalWith('z' * 40);
      final result = TerminalReflow.reflow(
        lines: linesOf(terminal),
        oldWidth: 10,
        newWidth: 2,
        newHeight: 3,
        cursorX: terminal.mainBuffer.cursorX,
        cursorRow: terminal.mainBuffer.absoluteCursorY,
        maxLines: 8,
      );
      expect(result.lines.length, 8);
      expect(result.lines.first.isWrapped, isFalse);
    });
  });

  group('grid', () {
    test('columns and rows round down and spare pixels become padding', () {
      final grid = TerminalGrid.fit(
        area: const Size(805, 403),
        cell: const Size(8, 16),
        minPadding: 4,
      );
      expect(grid.columns, 99);
      expect(grid.rows, 24);
      expect(grid.padding.left + grid.padding.right, 805 - 99 * 8);
      expect(grid.padding.top + grid.padding.bottom, 403 - 24 * 16);
      expect(
        (grid.padding.left - grid.padding.right).abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('padding snaps to device pixels', () {
      final grid = TerminalGrid.fit(
        area: const Size(100.25, 50),
        cell: const Size(7.5, 15),
        minPadding: 0,
        devicePixelRatio: 2,
      );
      expect(grid.columns, 13);
      expect(grid.padding.left * 2, grid.padding.left * 2.roundToDouble());
    });

    test('no partial column or row, exact fits use the whole area', () {
      final grid = TerminalGrid.fit(
        area: const Size(80, 48),
        cell: const Size(8, 16),
        minPadding: 0,
      );
      expect(grid.columns, 10);
      expect(grid.rows, 3);
      expect(grid.padding, EdgeInsets.zero);
    });

    test('tiny areas are not usable', () {
      final grid = TerminalGrid.fit(
        area: const Size(10, 10),
        cell: const Size(8, 16),
        minPadding: 0,
      );
      expect(grid.usable, isFalse);
    });

    test('cell metrics snap to whole device pixels', () {
      final metrics = CellMetrics.snapped(
        rawWidth: 7.83,
        fontSize: 13,
        devicePixelRatio: 2,
      );
      expect(metrics.cell.width * 2, (metrics.cell.width * 2).roundToDouble());
      expect(
        metrics.cell.height * 2,
        (metrics.cell.height * 2).roundToDouble(),
      );
      expect((metrics.scale - 1).abs(), lessThan(0.05));
    });
  });

  group('resize throttle', () {
    test('sends at most once per interval and always sends the last size', () {
      fakeAsync((async) {
        final sent = <(int, int)>[];
        final throttle = ResizeThrottle(
          interval: const Duration(milliseconds: 80),
          send: (c, r) => sent.add((c, r)),
          now: () => DateTime(2026).add(async.elapsed),
        )..request(80, 24);
        for (var i = 1; i <= 10; i++) {
          async.elapse(const Duration(milliseconds: 10));
          throttle.request(80 + i, 24);
        }
        async.elapse(const Duration(milliseconds: 200));
        expect(sent.first, (80, 24));
        expect(sent.last, (90, 24));
        expect(sent.length, lessThanOrEqualTo(3));
      });
    });

    test('never sends a size below two columns or zero rows', () {
      final sent = <(int, int)>[];
      ResizeThrottle(interval: Duration.zero, send: (c, r) => sent.add((c, r)))
        ..request(1, 24)
        ..request(0, 0)
        ..request(80, 0)
        ..settle();
      expect(sent, isEmpty);
    });

    test('settle flushes a pending size immediately', () {
      fakeAsync((async) {
        final sent = <(int, int)>[];
        final throttle = ResizeThrottle(
          interval: const Duration(milliseconds: 80),
          send: (c, r) => sent.add((c, r)),
          now: () => DateTime(2026).add(async.elapsed),
        )..request(80, 24);
        async.elapse(const Duration(milliseconds: 5));
        throttle
          ..request(100, 30)
          ..settle();
        expect(sent, [(80, 24), (100, 30)]);
      });
    });
  });
}
