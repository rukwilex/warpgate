import 'dart:math' show min;
import 'dart:typed_data';

import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/cell.dart';
import 'package:xterm/src/core/cursor.dart';
import 'package:xterm/src/utils/circular_buffer.dart';
import 'package:xterm/src/utils/unicode_v11.dart';

const _cellSize = 4;

const _cellForeground = 0;

const _cellBackground = 1;

const _cellAttributes = 2;

const _cellContent = 3;

class BufferLine with IndexedItem {
  BufferLine(this._length, {this.isWrapped = false})
      : _data = LineStore.take(_calcCapacity(_length) * _cellSize);

  int _length;

  Uint32List? _data;

  Uint32List? _runs;

  TypedData? _text;

  int _packedCells = 0;

  Uint32List get data => _cells;

  var isWrapped = false;

  int get length => _length;

  List<CellAnchor>? _anchorList;

  List<CellAnchor> get anchors => _anchorList ?? const [];

  List<CellAnchor> get _anchors => _anchorList ??= <CellAnchor>[];

  int version = 0;

  bool get isPacked => _data == null;

  bool packable = false;

  @pragma('vm:prefer-inline')
  Uint32List get _cells => _data ?? _unpack();

  int get storageBytes {
    final data = _data;
    if (data != null) return data.lengthInBytes + 64;
    return (_runs?.lengthInBytes ?? 0) + (_text?.lengthInBytes ?? 0) + 96;
  }

  static var _runScratch = Uint32List(1024);
  static var _textScratch = Uint32List(512);

  bool pack() {
    final data = _data;
    if (data == null) return true;
    final anchors = _anchorList;
    if (anchors != null && anchors.isNotEmpty) return false;
    var cells = _length;
    while (cells > 0) {
      final o = (cells - 1) * _cellSize;
      if (data[o] | data[o + 1] | data[o + 2] | data[o + 3] != 0) break;
      cells--;
    }
    if (_runScratch.length < cells * 4) _runScratch = Uint32List(cells * 4);
    if (_textScratch.length < cells) _textScratch = Uint32List(cells);
    final runs = _runScratch;
    final texts = _textScratch;
    var r = -4;
    var fg = -1;
    var bg = -1;
    var attrs = -1;
    var narrowMask = 0;
    for (var i = 0, o = 0; i < cells; i++, o += _cellSize) {
      final f = data[o];
      final b = data[o + 1];
      final a = data[o + 2];
      if (f != fg || b != bg || a != attrs) {
        r += 4;
        runs[r] = 0;
        runs[r + 1] = fg = f;
        runs[r + 2] = bg = b;
        runs[r + 3] = attrs = a;
      }
      runs[r]++;
      final content = data[o + 3];
      texts[i] = content;
      narrowMask |=
          content == 0 ? 0 : (content ^ (1 << CellContent.widthShift)) & ~0xff;
    }
    final runWords = r + 4;
    _runs = runWords == 0
        ? null
        : (Uint32List(runWords)..setRange(0, runWords, runs));
    if (narrowMask == 0) {
      final text = Uint8List(cells);
      for (var i = 0; i < cells; i++) {
        text[i] = texts[i];
      }
      _text = text;
    } else {
      _text = Uint32List(cells)..setRange(0, cells, texts);
    }
    _packedCells = cells;
    _data = null;
    LineStore.give(data);
    return true;
  }

  Uint32List _unpack() {
    final data = LineStore.take(_calcCapacity(_length) * _cellSize);
    final runs = _runs;
    var cell = 0;
    if (runs != null) {
      for (var r = 0; r < runs.length; r += 4) {
        final count = runs[r];
        final fg = runs[r + 1];
        final bg = runs[r + 2];
        final attrs = runs[r + 3];
        for (var k = 0; k < count; k++) {
          final o = cell * _cellSize;
          data[o] = fg;
          data[o + 1] = bg;
          data[o + 2] = attrs;
          cell++;
        }
      }
    }
    final text = _text;
    if (text is Uint8List) {
      const one = 1 << CellContent.widthShift;
      for (var i = 0; i < _packedCells; i++) {
        final c = text[i];
        data[i * _cellSize + 3] = c == 0 ? 0 : c | one;
      }
    } else if (text is Uint32List) {
      for (var i = 0; i < _packedCells; i++) {
        data[i * _cellSize + 3] = text[i];
      }
    }
    _runs = null;
    _text = null;
    _packedCells = 0;
    _data = data;
    LineStore.unpacked(this);
    return data;
  }

  void recycle(int length) {
    version++;
    _anchorList?.clear();
    isWrapped = false;
    packable = false;
    final data = _data;
    final capacity = _calcCapacity(length) * _cellSize;
    if (data != null && data.length == capacity) {
      data.fillRange(0, data.length, 0);
    } else {
      if (data != null) LineStore.give(data);
      _data = LineStore.take(capacity);
    }
    _runs = null;
    _text = null;
    _packedCells = 0;
    _length = length;
  }

  int getForeground(int index) {
    return _cells[index * _cellSize + _cellForeground];
  }

  int getBackground(int index) {
    return _cells[index * _cellSize + _cellBackground];
  }

  int getAttributes(int index) {
    return _cells[index * _cellSize + _cellAttributes];
  }

  int getContent(int index) {
    return _cells[index * _cellSize + _cellContent];
  }

  int getCodePoint(int index) {
    return _cells[index * _cellSize + _cellContent] & CellContent.codepointMask;
  }

  int getWidth(int index) {
    return _cells[index * _cellSize + _cellContent] >> CellContent.widthShift;
  }

  void getCellData(int index, CellData cellData) {
    final offset = index * _cellSize;
    cellData.foreground = _cells[offset + _cellForeground];
    cellData.background = _cells[offset + _cellBackground];
    cellData.flags = _cells[offset + _cellAttributes];
    cellData.content = _cells[offset + _cellContent];
  }

  CellData createCellData(int index) {
    version++;
    final cellData = CellData.empty();
    final offset = index * _cellSize;
    _cells[offset + _cellForeground] = cellData.foreground;
    _cells[offset + _cellBackground] = cellData.background;
    _cells[offset + _cellAttributes] = cellData.flags;
    _cells[offset + _cellContent] = cellData.content;
    return cellData;
  }

  void setForeground(int index, int value) {
    version++;
    _cells[index * _cellSize + _cellForeground] = value;
  }

  void setBackground(int index, int value) {
    version++;
    _cells[index * _cellSize + _cellBackground] = value;
  }

  void setAttributes(int index, int value) {
    version++;
    _cells[index * _cellSize + _cellAttributes] = value;
  }

  void setContent(int index, int value) {
    version++;
    _cells[index * _cellSize + _cellContent] = value;
  }

  void setCodePoint(int index, int char) {
    final width = unicodeV11.wcwidth(char);
    setContent(index, char | (width << CellContent.widthShift));
  }

  void setCell(int index, int char, int witdh, CursorStyle style) {
    version++;
    final offset = index * _cellSize;
    _cells[offset + _cellForeground] = style.foreground;
    _cells[offset + _cellBackground] = style.background;
    _cells[offset + _cellAttributes] = style.attrs;
    _cells[offset + _cellContent] = char | (witdh << CellContent.widthShift);
  }

  void setCellData(int index, CellData cellData) {
    version++;
    final offset = index * _cellSize;
    _cells[offset + _cellForeground] = cellData.foreground;
    _cells[offset + _cellBackground] = cellData.background;
    _cells[offset + _cellAttributes] = cellData.flags;
    _cells[offset + _cellContent] = cellData.content;
  }

  void eraseCell(int index, CursorStyle style) {
    version++;
    final offset = index * _cellSize;
    _cells[offset + _cellForeground] = style.foreground;
    _cells[offset + _cellBackground] = style.background;
    _cells[offset + _cellAttributes] = style.attrs;
    _cells[offset + _cellContent] = 0;
  }

  void resetCell(int index) {
    version++;
    final offset = index * _cellSize;
    _cells[offset + _cellForeground] = 0;
    _cells[offset + _cellBackground] = 0;
    _cells[offset + _cellAttributes] = 0;
    _cells[offset + _cellContent] = 0;
  }

  void eraseRange(int start, int end, CursorStyle style) {
    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    if (end < _length && getWidth(end - 1) == 2) {
      eraseCell(end - 1, style);
    }

    end = min(end, _length);
    for (var i = start; i < end; i++) {
      eraseCell(i, style);
    }
  }

  void removeCells(int start, int count, [CursorStyle? style]) {
    version++;
    assert(start >= 0 && start < _length);
    assert(count >= 0 && start + count <= _length);

    style ??= CursorStyle.empty;

    if (start + count < _length) {
      final moveStart = start * _cellSize;
      final moveEnd = (_length - count) * _cellSize;
      final moveOffset = count * _cellSize;
      for (var i = moveStart; i < moveEnd; i++) {
        _cells[i] = _cells[i + moveOffset];
      }
    }

    for (var i = _length - count; i < _length; i++) {
      eraseCell(i, style);
    }

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x >= start) {
        if (anchor.x < start + count) {
          anchor.dispose();
        } else {
          anchor.reposition(anchor.x - count);
        }
      }
    }
  }

  void insertCells(int start, int count, [CursorStyle? style]) {
    version++;
    style ??= CursorStyle.empty;

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    if (start + count < _length) {
      final moveStart = start * _cellSize;
      final moveEnd = (_length - count) * _cellSize;
      final moveOffset = count * _cellSize;
      for (var i = moveEnd - 1; i >= moveStart; i--) {
        _cells[i + moveOffset] = _cells[i];
      }
    }

    final end = min(start + count, _length);
    for (var i = start; i < end; i++) {
      eraseCell(i, style);
    }

    if (getWidth(_length - 1) == 2) {
      eraseCell(_length - 1, style);
    }

    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x >= start + count) {
        anchor.reposition(anchor.x + count);

        if (anchor.x >= _length) {
          anchor.dispose();
        }
      }
    }
  }

  void resize(int length) {
    version++;
    assert(length >= 0);

    if (length == _length) {
      return;
    }

    if (length > _length) {
      final newBufferSize = _calcCapacity(length) * _cellSize;

      if (newBufferSize > _cells.length) {
        final old = _cells;
        final newBuffer = LineStore.take(newBufferSize);
        newBuffer.setRange(0, old.length, old);
        _data = newBuffer;
        LineStore.give(old);
      }
    }

    _length = length;

    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x > _length) {
        anchor.reposition(_length);
      }
    }
  }

  int getTrimmedLength([int? cols]) {
    if (_data == null) {
      final limit = cols == null ? _packedCells : min(cols, _packedCells);
      final text = _text;
      for (var i = limit - 1; i >= 0; i--) {
        if (text is Uint8List) {
          if (text[i] != 0) return i + 1;
        } else if (text is Uint32List) {
          final content = text[i];
          if (content & CellContent.codepointMask != 0) {
            return i + (content >> CellContent.widthShift);
          }
        }
      }
      return 0;
    }
    final maxCols = _cells.length ~/ _cellSize;

    if (cols == null || cols > maxCols) {
      cols = maxCols;
    }

    if (cols <= 0) {
      return 0;
    }

    for (var i = cols - 1; i >= 0; i--) {
      var codePoint = getCodePoint(i);

      if (codePoint != 0) {
        final lastCellWidth = getWidth(i);
        return i + lastCellWidth;
      }
    }
    return 0;
  }

  void copyFrom(BufferLine src, int srcCol, int dstCol, int len) {
    version++;
    resize(dstCol + len);

    var srcOffset = srcCol * _cellSize;
    var dstOffset = dstCol * _cellSize;

    for (var i = 0; i < len * _cellSize; i++) {
      _cells[dstOffset++] = src._cells[srcOffset++];
    }
  }

  static int _calcCapacity(int length) {
    assert(length >= 0);

    var capacity = 64;

    if (length < 256) {
      while (capacity < length) {
        capacity *= 2;
      }
    } else {
      capacity = 256;
      while (capacity < length) {
        capacity += 32;
      }
    }

    return capacity;
  }

  String getText([int? from, int? to]) {
    if (from == null || from < 0) {
      from = 0;
    }

    if (to == null || to > _length) {
      to = _length;
    }

    final builder = StringBuffer();
    if (_data == null) {
      final text = _text;
      final end = min(to, _packedCells);
      for (var i = from; i < end; i++) {
        if (text is Uint8List) {
          final c = text[i];
          if (c != 0) builder.writeCharCode(c);
        } else if (text is Uint32List) {
          final content = text[i];
          final codePoint = content & CellContent.codepointMask;
          final width = content >> CellContent.widthShift;
          if (codePoint != 0 && i + width <= to)
            builder.writeCharCode(codePoint);
        }
      }
      return builder.toString();
    }
    for (var i = from; i < to; i++) {
      final codePoint = getCodePoint(i);
      final width = getWidth(i);
      if (codePoint != 0 && i + width <= to) {
        builder.writeCharCode(codePoint);
      }
    }

    return builder.toString();
  }

  CellAnchor createAnchor(int offset) {
    final anchor = CellAnchor(offset, owner: this);
    _anchors.add(anchor);
    return anchor;
  }

  void dispose() {
    final anchors = _anchorList;
    if (anchors == null) return;
    for (final anchor in List.of(anchors)) {
      anchor.dispose();
    }
  }

  @override
  String toString() {
    return getText();
  }
}

class CellAnchor {
  CellAnchor(int offset, {BufferLine? owner})
      : _offset = offset,
        _owner = owner;

  int _offset;

  int get x {
    return _offset;
  }

  int get y {
    assert(attached);
    return _owner!.index;
  }

  CellOffset get offset {
    assert(attached);
    return CellOffset(_offset, _owner!.index);
  }

  BufferLine? _owner;

  BufferLine? get line => _owner;

  bool get attached => _owner?.attached ?? false;

  void reparent(BufferLine owner, int offset) {
    _owner?._anchorList?.remove(this);
    _owner = owner;
    _owner?._anchors.add(this);
    _offset = offset;
  }

  void reposition(int offset) {
    _offset = offset;
  }

  void dispose() {
    _owner?._anchorList?.remove(this);
    _owner = null;
  }

  @override
  String toString() {
    if (attached) {
      return 'CellAnchor($x, $y)';
    } else {
      return 'CellAnchor($x, detached)';
    }
  }
}

abstract final class LineStore {
  static final _free = <int, List<Uint32List>>{};
  static int _freeCount = 0;
  static const _maxFree = 256;

  static final _unpacked = <WeakReference<BufferLine>>[];
  static int _unpackedHead = 0;
  static int maxUnpacked = 1024;

  static int unpackedLines = 0;

  static Uint32List take(int length) {
    final list = _free[length];
    if (list != null && list.isNotEmpty) {
      _freeCount--;
      final data = list.removeLast();
      data.fillRange(0, data.length, 0);
      return data;
    }
    return Uint32List(length);
  }

  static void give(Uint32List data) {
    if (_freeCount >= _maxFree) return;
    (_free[data.length] ??= <Uint32List>[]).add(data);
    _freeCount++;
  }

  static void unpacked(BufferLine line) {
    unpackedLines++;
    if (!line.packable) return;
    final ref = WeakReference(line);
    if (_unpacked.length < maxUnpacked) {
      _unpacked.add(ref);
      return;
    }
    final evicted = _unpacked[_unpackedHead].target;
    _unpacked[_unpackedHead] = ref;
    _unpackedHead = (_unpackedHead + 1) % maxUnpacked;
    if (evicted != null &&
        !identical(evicted, line) &&
        evicted.packable &&
        evicted.attached) {
      evicted.pack();
    }
  }

  static void clearFree() {
    _free.clear();
    _freeCount = 0;
  }
}
