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

class _WgStatusDotState extends State<WgStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this);

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
    final animate = widget.state.isLive && period > Duration.zero;
    if (animate && !_spin.isAnimating) {
      _spin
        ..duration = period
        ..repeat();
    } else if (!animate && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
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
    return Semantics(
      label: label,
      child: Tooltip(
        message: widget.state.label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: AnimatedBuilder(
            animation: _spin,
            builder: (context, _) => CustomPaint(
              painter: _DotPainter(
                state: widget.state,
                color: _color(context),
                turn: _spin.value,
                stroke: context.sizes.stroke,
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
    required this.turn,
    required this.stroke,
  });

  final WgDotState state;
  final Color color;
  final double turn;
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
        canvas.drawArc(rect, turn * math.pi * 2, math.pi * 1.4, false, ring);
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.color != color ||
      oldDelegate.turn != turn;
}
