import 'package:flutter/material.dart';
import 'package:warpgate/design_system/tokens/wg_palette.dart';
import 'package:warpgate_core/features/settings/domain/appearance.dart';

export 'package:warpgate_core/features/settings/domain/appearance.dart';

extension WgAccentColors on WgAccent {
  Color get onDark => switch (this) {
    WgAccent.amber => WgPalette.amberDark,
    WgAccent.cobalt => WgPalette.cobaltDark,
    WgAccent.teal => WgPalette.tealDark,
    WgAccent.moss => WgPalette.mossDark,
  };

  Color get onLight => switch (this) {
    WgAccent.amber => WgPalette.amberLight,
    WgAccent.cobalt => WgPalette.cobaltLight,
    WgAccent.teal => WgPalette.tealLight,
    WgAccent.moss => WgPalette.mossLight,
  };

}

@immutable
class WgColors extends ThemeExtension<WgColors> {
  const new({
    required this.canvasDeep,
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.pressed,
    required this.hairline,
    required this.hairlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentWash,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.positive,
    required this.negative,
    required this.caution,
    required this.negativeWash,
    required this.focusRing,
    required this.selection,
    required this.scrim,
    required this.shadow,
    required this.transparent,
    required this.primaryFillHover,
    required this.disabledInk,
    required this.veil,
    required this.negativeFill,
    required this.onNegativeFill,
  });

  factory dark(WgAccent accent) {
    const text = WgPalette.graphite100;
    return WgColors(
      canvasDeep: WgPalette.graphite950,
      canvas: WgPalette.graphite900,
      surface: WgPalette.graphite850,
      raised: WgPalette.graphite800,
      pressed: WgPalette.graphite750,
      hairline: text.withValues(alpha: 0.08),
      hairlineStrong: text.withValues(alpha: 0.14),
      textPrimary: text,
      textSecondary: WgPalette.graphite400,
      textMuted: WgPalette.graphite500,
      accent: accent.onDark,
      accentInk: accent.onDark,
      onAccent: WgPalette.graphite950,
      accentWash: accent.onDark.withValues(alpha: 0.14),
      primaryFill: text,
      onPrimaryFill: WgPalette.graphite950,
      positive: WgPalette.positiveDark,
      negative: WgPalette.negativeDark,
      caution: WgPalette.cautionDark,
      negativeWash: WgPalette.negativeDark.withValues(alpha: 0.12),
      focusRing: accent.onDark,
      selection: accent.onDark.withValues(alpha: 0.28),
      scrim: WgPalette.black.withValues(alpha: 0.56),
      shadow: WgPalette.black.withValues(alpha: 0.4),
      transparent: WgPalette.transparent,
      primaryFillHover: text.withValues(alpha: 0.88),
      disabledInk: WgPalette.graphite500.withValues(alpha: 0.5),
      veil: WgPalette.graphite900.withValues(alpha: 0.72),
      negativeFill: WgPalette.negativeLight,
      onNegativeFill: WgPalette.white,
    );
  }

  factory light(WgAccent accent) {
    const text = WgPalette.ink900;
    return WgColors(
      canvasDeep: WgPalette.paper100,
      canvas: WgPalette.paper50,
      surface: WgPalette.paper0,
      raised: WgPalette.paper100,
      pressed: WgPalette.paper150,
      hairline: text.withValues(alpha: 0.09),
      hairlineStrong: text.withValues(alpha: 0.16),
      textPrimary: text,
      textSecondary: WgPalette.ink600,
      textMuted: WgPalette.ink500,
      accent: accent.onLight,
      accentInk: accent.onLight,
      onAccent: WgPalette.white,
      accentWash: accent.onLight.withValues(alpha: 0.1),
      primaryFill: text,
      onPrimaryFill: WgPalette.white,
      positive: WgPalette.positiveLight,
      negative: WgPalette.negativeLight,
      caution: WgPalette.cautionLight,
      negativeWash: WgPalette.negativeLight.withValues(alpha: 0.08),
      focusRing: accent.onLight,
      selection: accent.onLight.withValues(alpha: 0.2),
      scrim: WgPalette.black.withValues(alpha: 0.32),
      shadow: WgPalette.black.withValues(alpha: 0.08),
      transparent: WgPalette.transparent,
      primaryFillHover: text.withValues(alpha: 0.88),
      disabledInk: WgPalette.ink500.withValues(alpha: 0.5),
      veil: WgPalette.paper50.withValues(alpha: 0.72),
      negativeFill: WgPalette.negativeLight,
      onNegativeFill: WgPalette.white,
    );
  }

  static const lineAlpha = 0.4;

  Color line(Color tone) => tone.withValues(alpha: lineAlpha);

  final Color canvasDeep;
  final Color canvas;
  final Color surface;
  final Color raised;
  final Color pressed;
  final Color hairline;
  final Color hairlineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentInk;
  final Color onAccent;
  final Color accentWash;
  final Color primaryFill;
  final Color onPrimaryFill;
  final Color positive;
  final Color negative;
  final Color caution;
  final Color negativeWash;
  final Color focusRing;
  final Color selection;
  final Color scrim;
  final Color shadow;
  final Color transparent;
  final Color primaryFillHover;
  final Color negativeFill;
  final Color onNegativeFill;
  final Color disabledInk;
  final Color veil;

  WgColors inactive() =>
      copyWith(textPrimary: textMuted, textSecondary: textMuted);

  @override
  WgColors copyWith({
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
  }) => WgColors(
    canvasDeep: canvasDeep,
    canvas: canvas,
    surface: surface,
    raised: raised,
    pressed: pressed,
    hairline: hairline,
    hairlineStrong: hairlineStrong,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted,
    accent: accent ?? this.accent,
    accentInk: accent ?? accentInk,
    onAccent: onAccent,
    accentWash: accentWash,
    primaryFill: primaryFill,
    onPrimaryFill: onPrimaryFill,
    positive: positive,
    negative: negative,
    caution: caution,
    negativeWash: negativeWash,
    focusRing: accent ?? focusRing,
    selection: selection,
    scrim: scrim,
    shadow: shadow,
    transparent: transparent,
    primaryFillHover: primaryFillHover,
    disabledInk: disabledInk,
    veil: veil,
    negativeFill: negativeFill,
    onNegativeFill: onNegativeFill,
  );

  @override
  WgColors lerp(WgColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return WgColors(
      canvasDeep: mix(canvasDeep, other.canvasDeep),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      pressed: mix(pressed, other.pressed),
      hairline: mix(hairline, other.hairline),
      hairlineStrong: mix(hairlineStrong, other.hairlineStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      accentInk: mix(accentInk, other.accentInk),
      onAccent: mix(onAccent, other.onAccent),
      accentWash: mix(accentWash, other.accentWash),
      primaryFill: mix(primaryFill, other.primaryFill),
      onPrimaryFill: mix(onPrimaryFill, other.onPrimaryFill),
      positive: mix(positive, other.positive),
      negative: mix(negative, other.negative),
      caution: mix(caution, other.caution),
      negativeWash: mix(negativeWash, other.negativeWash),
      focusRing: mix(focusRing, other.focusRing),
      selection: mix(selection, other.selection),
      scrim: mix(scrim, other.scrim),
      shadow: mix(shadow, other.shadow),
      transparent: mix(transparent, other.transparent),
      primaryFillHover: mix(primaryFillHover, other.primaryFillHover),
      disabledInk: mix(disabledInk, other.disabledInk),
      veil: mix(veil, other.veil),
      negativeFill: mix(negativeFill, other.negativeFill),
      onNegativeFill: mix(onNegativeFill, other.onNegativeFill),
    );
  }
}
