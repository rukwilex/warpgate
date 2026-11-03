import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class TerminalGrid {
  const new({
    required this.columns,
    required this.rows,
    required this.padding,
    required this.cell,
  });

  factory fit({
    required Size area,
    required Size cell,
    required double minPadding,
    double devicePixelRatio = 1,
  }) {
    if (cell.width <= 0 || cell.height <= 0) {
      return TerminalGrid(
        columns: 0,
        rows: 0,
        padding: EdgeInsets.zero,
        cell: cell,
      );
    }
    const epsilon = 1e-6;
    final innerWidth = math.max(area.width - minPadding * 2, 0);
    final innerHeight = math.max(area.height - minPadding * 2, 0);
    final columns = (innerWidth / cell.width + epsilon).floor();
    final rows = (innerHeight / cell.height + epsilon).floor();
    final spareX = math.max(area.width - columns * cell.width, 0).toDouble();
    final spareY = math.max(area.height - rows * cell.height, 0).toDouble();
    final left = floorToPixel(spareX / 2, devicePixelRatio);
    final top = floorToPixel(spareY / 2, devicePixelRatio);
    return TerminalGrid(
      columns: columns,
      rows: rows,
      cell: cell,
      padding: EdgeInsets.fromLTRB(left, top, spareX - left, spareY - top),
    );
  }

  static const minColumns = 2;
  static const minRows = 1;

  final int columns;
  final int rows;
  final EdgeInsets padding;
  final Size cell;

  bool get usable => columns >= minColumns && rows >= minRows;

  static double snap(double value, double devicePixelRatio) {
    final ratio = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    return math.max((value * ratio).round(), 1) / ratio;
  }

  static double floorToPixel(double value, double devicePixelRatio) {
    final ratio = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    return (value * ratio).floorToDouble() / ratio;
  }

  @override
  bool operator ==(Object other) =>
      other is TerminalGrid &&
      other.columns == columns &&
      other.rows == rows &&
      other.padding == padding &&
      other.cell == cell;

  @override
  int get hashCode => Object.hash(columns, rows, padding, cell);
}

@immutable
class CellMetrics {
  const new({
    required this.scale,
    required this.heightFactor,
    required this.cell,
  });

  factory snapped({
    required double rawWidth,
    required double fontSize,
    required double devicePixelRatio,
  }) {
    if (rawWidth <= 0 || fontSize <= 0) {
      return CellMetrics(
        scale: 1,
        heightFactor: lineHeight,
        cell: Size(rawWidth, fontSize * lineHeight),
      );
    }
    final width = TerminalGrid.snap(rawWidth, devicePixelRatio);
    final scale = width / rawWidth;
    final height = TerminalGrid.snap(
      fontSize * scale * lineHeight,
      devicePixelRatio,
    );
    return CellMetrics(
      scale: scale,
      heightFactor: height / (fontSize * scale),
      cell: Size(width, height),
    );
  }

  static const lineHeight = 1.2;

  final double scale;
  final double heightFactor;
  final Size cell;
}

class ResizeThrottle {
  new({required this.interval, required this.send, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Duration interval;
  final void Function(int columns, int rows) send;
  final DateTime Function() _now;

  DateTime? _lastSent;
  (int, int)? _sent;
  (int, int)? _pending;
  Timer? _timer;

  void request(int columns, int rows) {
    if (columns < TerminalGrid.minColumns || rows < TerminalGrid.minRows) {
      return;
    }
    final size = (columns, rows);
    if (size == _sent && _timer == null) return;
    _pending = size;
    final last = _lastSent;
    final now = _now();
    if (last == null || now.difference(last) >= interval) {
      _timer?.cancel();
      _timer = null;
      _flush();
      return;
    }
    _timer ??= Timer(interval - now.difference(last), () {
      _timer = null;
      _flush();
    });
  }

  void settle() {
    _timer?.cancel();
    _timer = null;
    _flush();
  }

  void _flush() {
    final pending = _pending;
    _pending = null;
    if (pending == null || pending == _sent) return;
    _sent = pending;
    _lastSent = _now();
    send(pending.$1, pending.$2);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
