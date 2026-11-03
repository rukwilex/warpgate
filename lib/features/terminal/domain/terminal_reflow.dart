import 'dart:math' as math;

import 'package:xterm/xterm.dart';

class ReflowResult {
  const new({
    required this.lines,
    required this.cursorX,
    required this.cursorRow,
    required this.rowMap,
    required this.height,
  });

  final List<BufferLine> lines;
  final int cursorX;
  final int cursorRow;
  final List<int> rowMap;
  final int height;

  int get scrollBack => lines.length - height;

  int get cursorScreenY => cursorRow - scrollBack;
}

class _Segment {
  const new(this.line, this.start, this.length);

  final BufferLine line;
  final int start;
  final int length;
}

abstract final class TerminalReflow {
  static ReflowResult reflow({
    required List<BufferLine> lines,
    required int oldWidth,
    required int newWidth,
    required int newHeight,
    required int cursorX,
    required int cursorRow,
    int maxLines = 1 << 30,
  }) {
    final width = math.max(newWidth, 1);
    final out = <BufferLine>[];
    final rowMap = List<int>.filled(lines.length, 0);
    var newCursorRow = 0;
    var newCursorX = 0;
    var lastContentRow = -1;
    var index = 0;
    while (index < lines.length) {
      final first = index;
      var last = index;
      while (last + 1 < lines.length && lines[last + 1].isWrapped) {
        last++;
      }
      final segments = <_Segment>[];
      final rowStarts = <int>[];
      var cursorOffset = -1;
      var total = 0;
      for (var row = first; row <= last; row++) {
        final line = lines[row];
        final limit = math.min(line.length, oldWidth);
        var take = row == last ? _trimmed(line, limit) : limit;
        if (row != last &&
            take > 0 &&
            line.getCodePoint(take - 1) == 0 &&
            line.getWidth(take - 1) == 0 &&
            lines[row + 1].length > 0 &&
            lines[row + 1].getWidth(0) == 2) {
          take--;
        }
        rowStarts.add(total);
        if (row == cursorRow) cursorOffset = total + cursorX;
        if (take > 0) segments.add(_Segment(line, 0, take));
        total += take;
      }
      final startRow = out.length;
      final placed = _split(segments, total, width, out);
      final offsets = placed.offsets;
      for (var i = 0; i < rowStarts.length; i++) {
        rowMap[first + i] = startRow + _rowOf(offsets, rowStarts[i], width);
      }
      if (total > 0) lastContentRow = out.length - 1;
      if (cursorOffset >= 0) {
        if (cursorOffset < total) {
          final position = _positionOf(offsets, cursorOffset, width);
          newCursorRow = startRow + position.$1;
          newCursorX = position.$2;
        } else {
          final endRow = out.length - 1;
          final endCol = total == 0 ? 0 : placed.endColumn;
          var column = endCol + (cursorOffset - total);
          var row = endRow;
          if (total > 0 && endCol >= width) {
            row += 1;
            column -= width;
          }
          while (column >= width) {
            row += 1;
            column -= width;
          }
          while (out.length <= row) {
            out.add(BufferLine(width, isWrapped: total > 0));
          }
          newCursorRow = row;
          newCursorX = column;
        }
      }
      index = last + 1;
    }
    final keep = math.max(math.max(newCursorRow, lastContentRow) + 1, 1);
    if (out.length > keep) out.removeRange(keep, out.length);
    while (out.length < newHeight) {
      out.add(BufferLine(width));
    }
    if (out.isNotEmpty) out.first.isWrapped = false;
    var dropped = 0;
    if (out.length > maxLines) {
      dropped = out.length - maxLines;
      out.removeRange(0, dropped);
      out.first.isWrapped = false;
    }
    return ReflowResult(
      height: newHeight,
      lines: out,
      cursorX: math.min(newCursorX, width - 1),
      cursorRow: math.max(newCursorRow - dropped, 0),
      rowMap: [
        for (final row in rowMap)
          (row - dropped).clamp(0, math.max(out.length - 1, 0)),
      ],
    );
  }

  static int _trimmed(BufferLine line, int limit) {
    for (var i = limit - 1; i >= 0; i--) {
      if (line.getCodePoint(i) != 0) {
        return math.min(i + math.max(line.getWidth(i), 1), limit);
      }
    }
    return 0;
  }

  static ({List<(int, int, int)> offsets, int endColumn}) _split(
    List<_Segment> segments,
    int total,
    int width,
    List<BufferLine> out,
  ) {
    final offsets = <(int, int, int)>[];
    var current = BufferLine(width);
    var column = 0;
    var rows = 0;
    var source = 0;
    void newRow() {
      current.resize(width);
      out.add(current);
      rows++;
      current = BufferLine(width, isWrapped: true);
      column = 0;
    }

    for (final segment in segments) {
      var position = segment.start;
      final end = segment.start + segment.length;
      while (position < end) {
        if (column >= width) newRow();
        var count = math.min(width - column, end - position);
        final lastCell = position + count - 1;
        if (count > 0 &&
            column + count == width &&
            segment.line.getWidth(lastCell) == 2) {
          count--;
        }
        if (count <= 0) {
          if (column == 0) {
            count = math.min(end - position, width);
          } else {
            newRow();
            continue;
          }
        }
        current.copyFrom(segment.line, position, column, count);
        offsets.add((source, rows, column));
        source += count;
        position += count;
        column += count;
      }
    }
    current.resize(width);
    out.add(current);
    return (offsets: offsets, endColumn: total == 0 ? 0 : column);
  }

  static (int, int) _positionOf(
    List<(int, int, int)> offsets,
    int offset,
    int width,
  ) {
    var best = (0, 0, 0);
    for (final entry in offsets) {
      if (entry.$1 <= offset) {
        best = entry;
      } else {
        break;
      }
    }
    final column = best.$3 + (offset - best.$1);
    if (column >= width) return (best.$2 + 1, column - width);
    return (best.$2, column);
  }

  static int _rowOf(List<(int, int, int)> offsets, int offset, int width) {
    if (offsets.isEmpty) return 0;
    return _positionOf(offsets, offset, width).$1;
  }
}
