import 'package:flutter/material.dart';
import 'package:warpgate/design_system/components/wg_pressable.dart';
import 'package:warpgate/design_system/theme/wg_theme.dart';

enum WgCaptionGlyph { minimize, maximize, restore, close }

class WgCaptionButton extends StatelessWidget {
  const new({
    required this.glyph,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final WgCaptionGlyph glyph;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sizes = context.sizes;
    final close = glyph == WgCaptionGlyph.close;
    return ExcludeFocus(
      child: WgPressable(
        semanticLabel: label,
        onPressed: onPressed,
        borderRadius: BorderRadius.zero,
        mouseCursor: SystemMouseCursors.basic,
        builder: (context, state) {
          final fill = switch ((close, state.pressed, state.hovered)) {
            (true, _, _) when state.highlighted => colors.negativeFill,
            (false, true, _) => colors.pressed,
            (false, false, true) => colors.raised,
            _ => colors.transparent,
          };
          final ink = close && state.highlighted
              ? colors.onNegativeFill
              : colors.textPrimary;
          return AnimatedContainer(
            duration: context.motion.fast,
            curve: context.motion.curve,
            width: sizes.captionButton,
            height: sizes.titleBar,
            color: fill,
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size.square(sizes.captionGlyph),
              painter: _GlyphPainter(
                glyph: glyph,
                color: ink,
                stroke: sizes.hairline,
                shift: context.space.hair,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const new({
    required this.glyph,
    required this.color,
    required this.stroke,
    required this.shift,
  });

  final WgCaptionGlyph glyph;
  final Color color;
  final double stroke;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..isAntiAlias = glyph == WgCaptionGlyph.close;
    final half = stroke / 2;
    final box = (Offset.zero & size).deflate(half);
    switch (glyph) {
      case WgCaptionGlyph.minimize:
        final y = (size.height / 2).floorToDouble() + half;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case WgCaptionGlyph.maximize:
        canvas.drawRect(box, paint);
      case WgCaptionGlyph.restore:
        final front = Rect.fromLTRB(
          box.left,
          box.top + shift,
          box.right - shift,
          box.bottom,
        );
        canvas
          ..drawRect(front, paint)
          ..drawPath(
            Path()
              ..moveTo(box.left + shift, front.top)
              ..lineTo(box.left + shift, box.top)
              ..lineTo(box.right, box.top)
              ..lineTo(box.right, front.bottom - shift)
              ..lineTo(front.right, front.bottom - shift),
            paint,
          );
      case WgCaptionGlyph.close:
        canvas
          ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
          ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke ||
      oldDelegate.shift != shift;
}
