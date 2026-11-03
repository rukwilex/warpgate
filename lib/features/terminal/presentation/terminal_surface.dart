import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/domain/terminal_geometry.dart';
import 'package:xterm/xterm.dart';

class TerminalSurface extends StatefulWidget {
  const new({
    required this.session,
    required this.controller,
    required this.focusNode,
    required this.theme,
    required this.cursorType,
    required this.fontSize,
    required this.onFontSize,
    super.key,
    this.autofocus = false,
    this.onKeyEvent,
    this.onTapUp,
    this.onSecondaryTapDown,
  });

  final TerminalSession session;
  final TerminalController controller;
  final FocusNode focusNode;
  final TerminalTheme theme;
  final TerminalCursorType cursorType;
  final double fontSize;
  final ValueChanged<double> onFontSize;
  final bool autofocus;
  final FocusOnKeyEventCallback? onKeyEvent;
  final void Function(TapUpDetails details, CellOffset offset)? onTapUp;
  final void Function(TapDownDetails details, CellOffset offset)?
  onSecondaryTapDown;

  static Size measureCell(TerminalStyle style, TextScaler scaler) {
    const sample = 'mmmmmmmmmm';
    final textStyle = style.toTextStyle();
    final builder = ui.ParagraphBuilder(textStyle.getParagraphStyle())
      ..pushStyle(textStyle.getTextStyle(textScaler: scaler))
      ..addText(sample);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    final size = Size(
      paragraph.maxIntrinsicWidth / sample.length,
      paragraph.height,
    );
    paragraph.dispose();
    return size;
  }

  @override
  State<TerminalSurface> createState() => _TerminalSurfaceState();
}

class _TerminalSurfaceState extends State<TerminalSurface> {
  final _scroll = ScrollController();
  (double, double)? _metricsKey;
  late CellMetrics _metrics;
  late TerminalStyle _style;
  late Size _cell;
  TerminalGrid? _grid;
  double _pinchBase = 0;
  bool _revealCursor = false;

  @override
  void didUpdateWidget(TerminalSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) _revealCursor = true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _prepareMetrics(double devicePixelRatio) {
    final key = (widget.fontSize, devicePixelRatio);
    if (key == _metricsKey) return;
    _metricsKey = key;
    final base = TerminalStyle(
      fontSize: widget.fontSize,
      fontFamily: WgFonts.mono,
      fontFamilyFallback: WgFonts.monoFallback,
    );
    final raw = TerminalSurface.measureCell(base, TextScaler.noScaling);
    _metrics = CellMetrics.snapped(
      rawWidth: raw.width,
      fontSize: widget.fontSize,
      devicePixelRatio: devicePixelRatio,
    );
    _style = base.copyWith(height: _metrics.heightFactor);
    _cell = TerminalSurface.measureCell(
      _style,
      TextScaler.linear(_metrics.scale),
    );
  }

  void _apply(TerminalGrid grid) {
    if (!grid.usable) return;
    final previous = _grid;
    _grid = grid;
    final terminal = widget.session.terminal;
    if (terminal.viewWidth == grid.columns &&
        terminal.viewHeight == grid.rows) {
      if (_revealCursor) _schedulePostResize(null, atBottom: true);
      return;
    }
    final lineHeight = previous?.cell.height ?? grid.cell.height;
    final atBottom =
        !_scroll.hasClients ||
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 1;
    final firstRow = _scroll.hasClients
        ? (_scroll.position.pixels / lineHeight).floor()
        : 0;
    if (terminal.viewWidth != grid.columns) {
      widget.controller.clearSelection();
    }
    final rowMap = widget.session.resize(grid.columns, grid.rows);
    final target = !atBottom && rowMap != null && rowMap.isNotEmpty
        ? rowMap[firstRow.clamp(0, rowMap.length - 1)]
        : null;
    _schedulePostResize(target, atBottom: atBottom);
  }

  void _schedulePostResize(int? anchorRow, {required bool atBottom}) {
    final reveal = _revealCursor;
    _revealCursor = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final lineHeight = _cell.height;
      var pixels = position.pixels;
      if (anchorRow != null) pixels = anchorRow * lineHeight;
      if (reveal && !atBottom) {
        final buffer = widget.session.terminal.buffer;
        final top = buffer.absoluteCursorY * lineHeight;
        final bottom = top + lineHeight;
        final viewport = position.viewportDimension;
        if (top < pixels) pixels = top;
        if (bottom > pixels + viewport) pixels = bottom - viewport;
      }
      pixels = pixels.clamp(0, position.maxScrollExtent);
      if (pixels != position.pixels) _scroll.jumpTo(pixels);
    });
  }

  void _pinchStart() => _pinchBase = widget.fontSize;

  void _pinchUpdate(double scale) {
    if (_pinchBase <= 0) return;
    final next = WgTerminalZoom.clamp(_pinchBase * scale);
    if (next != widget.fontSize) widget.onFontSize(next);
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    _prepareMetrics(devicePixelRatio);
    final minPadding = context.sizes.terminalPadding;
    final scaler = TextScaler.linear(_metrics.scale);
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = TerminalGrid.fit(
          area: constraints.biggest,
          cell: _cell,
          minPadding: minPadding,
          devicePixelRatio: devicePixelRatio,
        );
        _apply(grid);
        Widget view = TerminalView(
          widget.session.terminal,
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          autoResize: false,
          scrollController: _scroll,
          theme: widget.theme,
          cursorType: widget.cursorType,
          textStyle: _style,
          textScaler: scaler,
          padding: grid.usable ? grid.padding : EdgeInsets.all(minPadding),
          keyboardAppearance: Theme.of(context).brightness,
          onKeyEvent: widget.onKeyEvent,
          onTapUp: widget.onTapUp,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          hardwareKeyboardOnly: PlatformInfo.isDesktop,
        );
        view = Listener(
          onPointerPanZoomStart: (_) => _pinchStart(),
          onPointerPanZoomUpdate: (event) {
            if ((event.scale - 1).abs() > 0.01) _pinchUpdate(event.scale);
          },
          child: view,
        );
        if (PlatformInfo.isMobile) {
          view = GestureDetector(
            onScaleStart: (_) => _pinchStart(),
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) _pinchUpdate(details.scale);
            },
            child: view,
          );
        }
        return RepaintBoundary(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: ClipRect(child: view),
          ),
        );
      },
    );
  }
}
