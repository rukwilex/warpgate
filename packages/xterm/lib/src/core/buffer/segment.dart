import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/buffer/range.dart';

class BufferSegment {
  final BufferRange range;

  final int line;

  final int? start;

  final int? end;

  const BufferSegment(this.range, this.line, this.start, this.end)
      : assert((start != null && end != null) ? start <= end : true);

  bool isWithin(CellOffset position) {
    if (position.y != line) {
      return false;
    }

    if (start != null && position.x < start!) {
      return false;
    }

    if (end != null && position.x > end!) {
      return false;
    }

    return true;
  }

  @override
  String toString() {
    final start = this.start != null ? this.start.toString() : 'start';
    final end = this.end != null ? this.end.toString() : 'end';
    return 'Segment($line, $start -> $end)';
  }

  @override
  int get hashCode =>
      range.hashCode ^ line.hashCode ^ start.hashCode ^ end.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BufferSegment &&
          runtimeType == other.runtimeType &&
          range == other.range &&
          line == other.line &&
          start == other.start &&
          end == other.end;
}
