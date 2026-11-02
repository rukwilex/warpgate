import 'package:flutter/material.dart';

abstract final class WgFonts {
  static const ui = 'Geist';
  static const mono = 'JetBrainsMono';
  static const monoFallback = <String>['Menlo', 'Consolas', 'monospace'];
}

@immutable
class WgType extends ThemeExtension<WgType> {
  const new({
    required this.caption,
    required this.label,
    required this.body,
    required this.bodyStrong,
    required this.title,
    required this.heading,
    required this.display,
    required this.mono,
    required this.monoSmall,
    required this.keycap,
  });

  factory build(Color primary, Color secondary) {
    TextStyle ui(double size, double height, FontWeight weight, Color color) =>
        TextStyle(
          fontFamily: WgFonts.ui,
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          color: color,
          letterSpacing: 0,
        );
    TextStyle mono(double size, double height, Color color) => TextStyle(
      fontFamily: WgFonts.mono,
      fontFamilyFallback: WgFonts.monoFallback,
      fontSize: size,
      height: height / size,
      fontWeight: FontWeight.w400,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return WgType(
      caption: ui(12, 16, FontWeight.w400, secondary),
      label: ui(13, 18, FontWeight.w500, primary),
      body: ui(14, 20, FontWeight.w400, primary),
      bodyStrong: ui(14, 20, FontWeight.w500, primary),
      title: ui(16, 22, FontWeight.w500, primary),
      heading: ui(20, 26, FontWeight.w500, primary),
      display: ui(28, 32, FontWeight.w400, primary),
      mono: mono(13, 18, primary),
      monoSmall: mono(12, 16, secondary),
      keycap: mono(11, 14, secondary),
    );
  }

  final TextStyle caption;
  final TextStyle label;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle display;
  final TextStyle mono;
  final TextStyle monoSmall;
  final TextStyle keycap;

  @override
  WgType copyWith() => this;

  @override
  WgType lerp(WgType? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return WgType(
      caption: mix(caption, other.caption),
      label: mix(label, other.label),
      body: mix(body, other.body),
      bodyStrong: mix(bodyStrong, other.bodyStrong),
      title: mix(title, other.title),
      heading: mix(heading, other.heading),
      display: mix(display, other.display),
      mono: mix(mono, other.mono),
      monoSmall: mix(monoSmall, other.monoSmall),
      keycap: mix(keycap, other.keycap),
    );
  }
}
