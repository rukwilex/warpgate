import 'package:flutter/material.dart';
import 'package:warpgate/design_system/tokens/wg_palette.dart';
import 'package:xterm/xterm.dart';

enum WgTerminalScheme {
  followApp('Follow app'),
  graphiteNight('Graphite night'),
  graphiteDay('Graphite day');

  new(this.label);

  final String label;

  TerminalTheme resolve(Brightness appBrightness, Color accent) {
    final night = switch (this) {
      WgTerminalScheme.followApp => appBrightness == Brightness.dark,
      WgTerminalScheme.graphiteNight => true,
      WgTerminalScheme.graphiteDay => false,
    };
    return night ? _night(accent) : _day(accent);
  }

  static TerminalTheme _night(Color accent) => TerminalTheme(
    cursor: accent,
    selection: accent.withValues(alpha: 0.3),
    foreground: WgPalette.graphite100,
    background: WgPalette.graphite900,
    black: WgPalette.termBlack,
    red: WgPalette.termRed,
    green: WgPalette.termGreen,
    yellow: WgPalette.termYellow,
    blue: WgPalette.termBlue,
    magenta: WgPalette.termMagenta,
    cyan: WgPalette.termCyan,
    white: WgPalette.termWhite,
    brightBlack: WgPalette.termBrightBlack,
    brightRed: WgPalette.termBrightRed,
    brightGreen: WgPalette.termBrightGreen,
    brightYellow: WgPalette.termBrightYellow,
    brightBlue: WgPalette.termBrightBlue,
    brightMagenta: WgPalette.termBrightMagenta,
    brightCyan: WgPalette.termBrightCyan,
    brightWhite: WgPalette.termBrightWhite,
    searchHitBackground: accent.withValues(alpha: 0.35),
    searchHitBackgroundCurrent: accent,
    searchHitForeground: WgPalette.graphite950,
  );

  static TerminalTheme _day(Color accent) => TerminalTheme(
    cursor: accent,
    selection: accent.withValues(alpha: 0.22),
    foreground: WgPalette.ink900,
    background: WgPalette.paper50,
    black: WgPalette.ink900,
    red: WgPalette.termLightRed,
    green: WgPalette.termLightGreen,
    yellow: WgPalette.termLightYellow,
    blue: WgPalette.termLightBlue,
    magenta: WgPalette.termLightMagenta,
    cyan: WgPalette.termLightCyan,
    white: WgPalette.termLightWhite,
    brightBlack: WgPalette.ink500,
    brightRed: WgPalette.termLightRed,
    brightGreen: WgPalette.termLightGreen,
    brightYellow: WgPalette.termLightYellow,
    brightBlue: WgPalette.termLightBlue,
    brightMagenta: WgPalette.termLightMagenta,
    brightCyan: WgPalette.termLightCyan,
    brightWhite: WgPalette.ink600,
    searchHitBackground: accent.withValues(alpha: 0.25),
    searchHitBackgroundCurrent: accent,
    searchHitForeground: WgPalette.white,
  );
}
