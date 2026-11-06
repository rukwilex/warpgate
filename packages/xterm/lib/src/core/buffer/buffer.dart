import 'dart:math' show max, min;

import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/core/buffer/range_line.dart';
import 'package:xterm/src/core/buffer/range.dart';
import 'package:xterm/src/core/charset.dart';
import 'package:xterm/src/core/cursor.dart';
import 'package:xterm/src/core/reflow.dart';
import 'package:xterm/src/core/state.dart';
import 'package:xterm/src/utils/circular_buffer.dart';
import 'package:xterm/src/utils/unicode_v11.dart';

class Buffer {
  final TerminalState terminal;

  final int maxLines;

  final bool isAltBuffer;

  final Set<int>? wordSeparators;

  Buffer(
    this.terminal, {
    required this.maxLines,
    required this.isAltBuffer,
    this.wordSeparators,
  }) {
    for (int i = 0; i < terminal.viewHeight; i++) {
      lines.push(_newEmptyLine());
    }

    resetVerticalMargins();
  }

  int _cursorX = 0;

  int _cursorY = 0;

  late int _marginTop;

  late int _marginBottom;

  var _savedCursorX = 0;

  var _savedCursorY = 0;

  final _savedCursorStyle = CursorStyle();

  final charset = Charset();

  int get viewWidth => terminal.viewWidth;

  int get viewHeight => terminal.viewHeight;

  late final lines = IndexAwareCircularBuffer<BufferLine>(maxLines);

  int get height => lines.length;

  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);

  int get cursorY => _cursorY;

  int get marginTop => _marginTop;

  int get marginBottom => _marginBottom;

  int get scrollBack => height - viewHeight;

  int get absoluteCursorY => _cursorY + scrollBack;

  int get absoluteMarginTop => _marginTop + scrollBack;

  int get absoluteMarginBottom => _marginBottom + scrollBack;

  void write(String text) {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  void writeChar(int codePoint) {
    codePoint = charset.translate(codePoint);

    final cellWidth = unicodeV11.wcwidth(codePoint);
    if (_cursorX >= terminal.viewWidth) {
      index();
      setCursorX(0);
      if (terminal.autoWrapMode) {
        currentLine.isWrapped = true;
      }
    }

    final line = currentLine;
    line.setCell(_cursorX, codePoint, cellWidth, terminal.cursor);

    if (_cursorX < viewWidth) {
      _cursorX++;
    }

    if (cellWidth == 2) {
      writeChar(0);
    }
  }

  BufferLine get currentLine {
    return lines[absoluteCursorY];
  }

  void backspace() {
    if (_cursorX == 0 && currentLine.isWrapped) {
      currentLine.isWrapped = false;
      moveCursor(viewWidth - 1, -1);
    } else if (_cursorX == viewWidth) {
      moveCursor(-2, 0);
    } else {
      moveCursor(-1, 0);
    }
  }

  void eraseDisplayFromCursor() {
    eraseLineFromCursor();

    for (var i = absoluteCursorY + 1; i < height; i++) {
      final line = lines[i];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  void eraseDisplay() {
    for (var i = 0; i < viewHeight; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  void eraseLineFromCursor() {
    currentLine.isWrapped = false;
    currentLine.eraseRange(_cursorX, viewWidth, terminal.cursor);
  }

  void eraseLineToCursor() {
    currentLine.isWrapped = false;
    currentLine.eraseRange(0, _cursorX, terminal.cursor);
  }

  void eraseLine() {
    currentLine.isWrapped = false;
    currentLine.eraseRange(0, viewWidth, terminal.cursor);
  }

  void eraseChars(int count) {
    final start = _cursorX;
    currentLine.eraseRange(start, start + count, terminal.cursor);
  }

  void scrollDown(int lines) {
    for (var i = absoluteMarginBottom; i >= absoluteMarginTop; i--) {
      if (i >= absoluteMarginTop + lines) {
        this.lines[i] = this.lines[i - lines];
      } else {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  void scrollUp(int lines) {
    for (var i = absoluteMarginTop; i <= absoluteMarginBottom; i++) {
      if (i <= absoluteMarginBottom - lines) {
        this.lines[i] = this.lines[i + lines];
      } else {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  void index() {
    if (isInVerticalMargin) {
      if (_cursorY == _marginBottom) {
        if (marginTop == 0 && !isAltBuffer) {
          if (absoluteMarginBottom + 1 == lines.length) {
            _pushLine();
          } else {
            lines.insert(absoluteMarginBottom + 1, _newEmptyLine());
            _packLeaving();
          }
        } else {
          scrollUp(1);
        }
      } else {
        moveCursorY(1);
      }
      return;
    }

    if (_cursorY >= viewHeight - 1) {
      if (isAltBuffer) {
        scrollUp(1);
      } else {
        _pushLine();
      }
    } else {
      moveCursorY(1);
    }
  }

  void lineFeed() {
    index();
    if (terminal.lineFeedMode) {
      setCursorX(0);
    }
  }

  void reverseIndex() {
    if (isInVerticalMargin) {
      if (_cursorY == _marginTop) {
        scrollDown(1);
      } else {
        moveCursorY(-1);
      }
    } else {
      moveCursorY(-1);
    }
  }

  void cursorGoForward() {
    _cursorX = min(_cursorX + 1, viewWidth);
  }

  void setCursorX(int cursorX) {
    _cursorX = cursorX.clamp(0, viewWidth - 1);
  }

  void setCursorY(int cursorY) {
    _cursorY = cursorY.clamp(0, viewHeight - 1);
  }

  void moveCursorX(int offset) {
    setCursorX(_cursorX + offset);
  }

  void moveCursorY(int offset) {
    setCursorY(_cursorY + offset);
  }

  void setCursor(int cursorX, int cursorY) {
    var maxCursorY = viewHeight - 1;

    if (terminal.originMode) {
      cursorY += _marginTop;
      maxCursorY = _marginBottom;
    }

    _cursorX = cursorX.clamp(0, viewWidth - 1);
    _cursorY = cursorY.clamp(0, maxCursorY);
  }

  void moveCursor(int offsetX, int offsetY) {
    final cursorX = _cursorX + offsetX;
    final cursorY = _cursorY + offsetY;
    setCursor(cursorX, cursorY);
  }

  void saveCursor() {
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    _savedCursorStyle.foreground = terminal.cursor.foreground;
    _savedCursorStyle.background = terminal.cursor.background;
    _savedCursorStyle.attrs = terminal.cursor.attrs;
    charset.save();
  }

  void restoreCursor() {
    _cursorX = _savedCursorX;
    _cursorY = _savedCursorY;
    terminal.cursor.foreground = _savedCursorStyle.foreground;
    terminal.cursor.background = _savedCursorStyle.background;
    terminal.cursor.attrs = _savedCursorStyle.attrs;
    charset.restore();
  }

  void setVerticalMargins(int top, int bottom) {
    _marginTop = top.clamp(0, viewHeight - 1);
    _marginBottom = bottom.clamp(0, viewHeight - 1);

    _marginTop = min(_marginTop, _marginBottom);
    _marginBottom = max(_marginTop, _marginBottom);
  }

  bool get isInVerticalMargin {
    return _cursorY >= _marginTop && _cursorY <= _marginBottom;
  }

  void resetVerticalMargins() {
    setVerticalMargins(0, viewHeight - 1);
  }

  void deleteChars(int count) {
    final start = _cursorX.clamp(0, viewWidth);
    count = min(count, viewWidth - start);
    currentLine.removeCells(start, count, terminal.cursor);
  }

  void clearScrollback() {
    if (height <= viewHeight) {
      return;
    }

    lines.trimStart(scrollBack);
  }

  void clear() {
    lines.clear();
    for (int i = 0; i < viewHeight; i++) {
      lines.push(_newEmptyLine());
    }
  }

  void insertBlankChars(int count) {
    currentLine.insertCells(_cursorX, count, terminal.cursor);
  }

  void insertLines(int count) {
    if (!isInVerticalMargin) {
      return;
    }

    setCursorX(0);

    final linesBelow = absoluteMarginBottom - absoluteCursorY + 1;

    final linesToInsert = min(count, linesBelow);

    final linesToMove = linesBelow - linesToInsert;

    for (var i = 0; i < linesToMove; i++) {
      final index = absoluteMarginBottom - i;
      lines[index] = lines.swap(index - linesToInsert, _newEmptyLine());
    }

    for (var i = linesToMove; i < linesToInsert; i++) {
      lines[absoluteCursorY + i] = _newEmptyLine();
    }
  }

  void deleteLines(int count) {
    if (!isInVerticalMargin) {
      return;
    }

    setCursorX(0);

    count = min(count, absoluteMarginBottom - absoluteCursorY + 1);

    final linesToMove = absoluteMarginBottom - absoluteCursorY + 1 - count;

    for (var i = 0; i < linesToMove; i++) {
      final index = absoluteCursorY + i;
      lines[index] = lines[index + count];
    }

    for (var i = 0; i < count; i++) {
      lines[absoluteMarginBottom - i] = _newEmptyLine();
    }
  }

  void resize(int oldWidth, int oldHeight, int newWidth, int newHeight) {
    if (newHeight > oldHeight) {
      for (var i = 0; i < newHeight - oldHeight; i++) {
        if (newHeight > lines.length) {
          lines.push(_newEmptyLine(newWidth));
        } else {
          _cursorY++;
        }
      }
    } else {
      for (var i = 0; i < oldHeight - newHeight; i++) {
        if (_cursorY > newHeight - 1) {
          _cursorY--;
        } else {
          lines.pop();
        }
      }
    }

    _cursorX = _cursorX.clamp(0, newWidth - 1);
    _cursorY = _cursorY.clamp(0, newHeight - 1);

    if (newWidth != oldWidth) {
      if (terminal.reflowEnabled && !isAltBuffer) {
        final reflowResult = reflow(lines, oldWidth, newWidth);

        while (reflowResult.length < newHeight) {
          reflowResult.add(_newEmptyLine(newWidth));
        }

        lines.replaceWith(reflowResult);
      } else {
        lines.forEach((item) => item.resize(newWidth));
      }
    }
  }

  CellAnchor createAnchor(int x, int y) {
    return lines[y].createAnchor(x);
  }

  CellAnchor createAnchorFromOffset(CellOffset offset) {
    return lines[offset.y].createAnchor(offset.x);
  }

  CellAnchor createAnchorFromCursor() {
    return createAnchor(cursorX, absoluteCursorY);
  }

  BufferLine _newEmptyLine([int? width]) {
    final line = BufferLine(width ?? viewWidth);
    return line;
  }

  void _pushLine() {
    final BufferLine line;
    if (lines.isFull) {
      line = lines[0]
        ..dispose()
        ..recycle(viewWidth);
    } else {
      line = _newEmptyLine();
    }
    lines.push(line);
    _packLeaving();
  }

  void _packLeaving() {
    final leaving = lines.length - viewHeight - 1;
    if (leaving >= 0) {
      lines[leaving]
        ..packable = true
        ..pack();
    }
  }

  int compactScrollback() {
    if (isAltBuffer) return 0;
    var packed = 0;
    final end = lines.length - viewHeight;
    for (var i = 0; i < end; i++) {
      final line = lines[i];
      if (line.isPacked) continue;
      line.packable = true;
      if (line.pack()) packed++;
    }
    return packed;
  }

  int trimScrollback(int keep) {
    final extra = scrollBack - keep;
    if (extra <= 0) return 0;
    lines.trimStart(extra);
    return extra;
  }

  int get storageBytes {
    var total = 0;
    for (var i = 0; i < lines.length; i++) {
      total += lines[i].storageBytes;
    }
    return total;
  }

  static final defaultWordSeparators = <int>{
    0,
    r' '.codeUnitAt(0),
    r'.'.codeUnitAt(0),
    r':'.codeUnitAt(0),
    r'-'.codeUnitAt(0),
    r'\'.codeUnitAt(0),
    r'"'.codeUnitAt(0),
    r'*'.codeUnitAt(0),
    r'+'.codeUnitAt(0),
    r'/'.codeUnitAt(0),
    r'\'.codeUnitAt(0),
  };

  BufferRangeLine? getWordBoundary(CellOffset position) {
    var separators = wordSeparators ?? defaultWordSeparators;
    if (position.y >= lines.length) {
      return null;
    }

    var line = lines[position.y];
    var start = position.x;
    var end = position.x;

    do {
      if (start == 0) {
        break;
      }
      final char = line.getCodePoint(start - 1);
      if (separators.contains(char)) {
        break;
      }
      start--;
    } while (true);

    do {
      if (end >= viewWidth) {
        break;
      }
      final char = line.getCodePoint(end);
      if (separators.contains(char)) {
        break;
      }
      end++;
    } while (true);

    if (start == end) {
      return null;
    }

    return BufferRangeLine(
      CellOffset(start, position.y),
      CellOffset(end, position.y),
    );
  }

  String getText([BufferRange? range]) {
    range ??= BufferRangeLine(
      CellOffset(0, 0),
      CellOffset(viewWidth - 1, height - 1),
    );

    range = range.normalized;

    final builder = StringBuffer();

    for (var segment in range.toSegments()) {
      if (segment.line < 0 || segment.line >= height) {
        continue;
      }
      final line = lines[segment.line];
      if (!(segment.line == range.begin.y ||
          segment.line == 0 ||
          line.isWrapped)) {
        builder.write("\n");
      }
      builder.write(line.getText(segment.start, segment.end));
    }

    return builder.toString();
  }

  @override
  String toString() {
    final builder = StringBuffer();
    final lineNumberLength = lines.length.toString().length;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      builder.write('${i.toString().padLeft(lineNumberLength)}: |${lines[i]}|');

      if (line.isWrapped) {
        builder.write(' (⏎)');
      }

      builder.write('\n');
    }

    return builder.toString();
  }
}
