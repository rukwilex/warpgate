import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/utils/circular_buffer.dart';

class _LineBuilder {
  _LineBuilder([this._capacity = 80]) {
    _result = BufferLine(_capacity);
  }

  final int _capacity;

  late BufferLine _result;

  int _length = 0;

  int get length => _length;

  bool get isEmpty => _length == 0;

  bool get isNotEmpty => _length != 0;

  void add(BufferLine src, int start, int length) {
    _result.copyFrom(src, start, _length, length);
    _length += length;
  }

  void setBuffer(BufferLine line, int length) {
    _result = line;
    _length = length;
  }

  void addAnchor(CellAnchor anchor, int offset) {
    anchor.reparent(_result, _length + offset);
  }

  BufferLine take({required bool wrapped}) {
    final result = _result;
    result.isWrapped = wrapped;

    _result = BufferLine(_capacity);
    _length = 0;

    return result;
  }
}

class _LineReflow {
  final int oldWidth;

  final int newWidth;

  _LineReflow(this.oldWidth, this.newWidth);

  final _lines = <BufferLine>[];

  late final _builder = _LineBuilder(newWidth);

  void add(BufferLine line) {
    final trimmedLength = line.getTrimmedLength(oldWidth);

    if (trimmedLength == 0) {
      _lines.add(line);
      return;
    }

    if (_lines.isNotEmpty || _builder.isNotEmpty) {
      _addPart(line, from: 0, to: trimmedLength);
      return;
    }

    if (newWidth >= oldWidth) {
      _builder.setBuffer(line, trimmedLength);
    } else {
      _lines.add(line);

      if (trimmedLength > newWidth) {
        if (line.getWidth(newWidth - 1) == 2) {
          _addPart(line, from: newWidth - 1, to: trimmedLength);
        } else {
          _addPart(line, from: newWidth, to: trimmedLength);
        }
      }
    }

    line.resize(newWidth);

    if (line.getWidth(newWidth - 1) == 2) {
      line.resetCell(newWidth - 1);
    }
  }

  void _addPart(BufferLine line, {required int from, required int to}) {
    var cellsLeft = to - from;

    while (cellsLeft > 0) {
      final bufferRemainingCells = newWidth - _builder.length;

      var cellsToCopy = cellsLeft;

      var lineFilled = false;

      if (cellsToCopy >= bufferRemainingCells) {
        cellsToCopy = bufferRemainingCells;
        lineFilled = true;
      }

      if (lineFilled && line.getWidth(from + cellsToCopy - 1) == 2) {
        cellsToCopy--;
      }

      for (var anchor in line.anchors.toList()) {
        if (anchor.x >= from && anchor.x <= from + cellsToCopy) {
          _builder.addAnchor(anchor, anchor.x - from);
        }
      }

      _builder.add(line, from, cellsToCopy);

      from += cellsToCopy;
      cellsLeft -= cellsToCopy;

      if (lineFilled) {
        _lines.add(_builder.take(wrapped: _lines.isNotEmpty));
      }
    }

    if (line.anchors.isNotEmpty) {
      for (var anchor in line.anchors.toList()) {
        if (anchor.x >= to) {
          _builder.addAnchor(anchor, anchor.x - to);
        }
      }
    }
  }

  List<BufferLine> finish() {
    if (_builder.isNotEmpty) {
      _lines.add(_builder.take(wrapped: _lines.isNotEmpty));
    }

    return _lines;
  }
}

List<BufferLine> reflow(
  IndexAwareCircularBuffer<BufferLine> lines,
  int oldWidth,
  int newWidth,
) {
  final result = <BufferLine>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    final reflow = _LineReflow(oldWidth, newWidth);

    reflow.add(line);

    for (var offset = i + 1; offset < lines.length; offset++) {
      final nextLine = lines[offset];

      if (!nextLine.isWrapped) {
        break;
      }

      i++;

      reflow.add(nextLine);
    }

    result.addAll(reflow.finish());
  }

  for (var line in result) {
    line.resize(newWidth);
  }

  return result;
}
