import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

enum WgDotState {
  idle('Not connected'),
  connecting('Connecting'),
  connected('Connected'),
  busy('Busy'),
  reconnecting('Reconnecting'),
  dropped('Dropped');

  new(this.label);

  final String label;

  bool get isLive =>
      this == WgDotState.connecting || this == WgDotState.reconnecting;
}

class WgStatusDot extends StatefulWidget {
  const new({required this.state, super.key, this.subject});

  final WgDotState state;
  final String? subject;

  @override
  State<WgStatusDot> createState() => _WgStatusDotState();
}

class _LiveClock {
  new _();

  static final step = ValueNotifier<int>(0);
  static final _users = <Object, Duration>{};
  static Timer? _timer;
  static Duration _period = Duration.zero;

  static void join(Object user, Duration period) {
    _users[user] = period;
    _sync();
  }

  static void leave(Object user) {
    if (_users.remove(user) != null) _sync();
  }

  static void _sync() {
    if (_users.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final period = _users.values.first;
    if (_timer != null && period == _period) return;
    _timer?.cancel();
    _period = period;
    _timer = Timer.periodic(
      period ~/ _WgStatusDotState.steps,
      (_) => step.value = (step.value + 1) % _WgStatusDotState.steps,
    );
  }
}

class _WgStatusDotState extends State<WgStatusDot> {
  static const steps = 12;

  final _still = ValueNotifier<int>(0);
  bool _live = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(WgStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final period = context.motion.live;
    final animate =
        widget.state.isLive &&
        period > Duration.zero &&
        TickerMode.valuesOf(context).enabled;
    if (animate) {
      _LiveClock.join(this, period);
    } else if (_live) {
      _LiveClock.leave(this);
    }
    _live = animate;
  }

  @override
  void dispose() {
    _LiveClock.leave(this);
    _still.dispose();
    super.dispose();
  }

  Color _color(BuildContext context) {
    final colors = context.colors;
    return switch (widget.state) {
      WgDotState.idle => colors.textMuted,
      WgDotState.connecting => colors.caution,
      WgDotState.connected => colors.positive,
      WgDotState.busy => colors.accent,
      WgDotState.reconnecting => colors.caution,
      WgDotState.dropped => colors.negative,
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = context.sizes.dot;
    final label = widget.subject == null
        ? widget.state.label
        : '${widget.subject}: ${widget.state.label.toLowerCase()}';
    final color = _color(context);
    final stroke = context.sizes.stroke;
    return Semantics(
      label: label,
      child: Tooltip(
        message: widget.state.label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DotPainter(
                state: widget.state,
                color: color,
                step: _live ? _LiveClock.step : _still,
                stroke: stroke,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  new({
    required this.state,
    required this.color,
    required this.step,
    required this.stroke,
  }) : super(repaint: step);

  final WgDotState state;
  final Color color;
  final ValueNotifier<int> step;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    switch (state) {
      case WgDotState.connected:
        canvas.drawCircle(center, radius, fill);
      case WgDotState.busy:
        canvas
          ..drawCircle(center, radius - stroke, ring)
          ..drawCircle(center, radius / 2, fill);
      case WgDotState.idle:
        canvas.drawCircle(center, radius - stroke / 2, ring);
      case WgDotState.dropped:
        final inset = radius * 0.15;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              inset,
              inset,
              size.width - inset * 2,
              size.height - inset * 2,
            ),
            Radius.circular(stroke),
          ),
          fill,
        );
      case WgDotState.connecting:
      case WgDotState.reconnecting:
        final rect = Rect.fromCircle(center: center, radius: radius - stroke);
        canvas.drawArc(
          rect,
          step.value / _WgStatusDotState.steps * math.pi * 2,
          math.pi * 1.4,
          false,
          ring,
        );
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.color != color ||
      oldDelegate.step != step;
}
