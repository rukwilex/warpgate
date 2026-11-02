import 'package:flutter/material.dart';
import 'package:warpgate/design_system/tokens/wg_colors.dart';
import 'package:warpgate/design_system/tokens/wg_metrics.dart';
import 'package:warpgate/design_system/tokens/wg_type.dart';

abstract final class WgTheme {
  static ThemeData build({
    required Brightness brightness,
    WgAccent accent = WgAccent.amber,
    WgDensity density = WgDensity.comfortable,
    bool touch = false,
    bool reduceMotion = false,
  }) {
    final colors = brightness == Brightness.dark
        ? WgColors.dark(accent)
        : WgColors.light(accent);
    final type = WgType.build(colors.textPrimary, colors.textSecondary);
    const radii = WgRadii();
    final sizes = WgSizes.forDensity(density, touch: touch);
    final motion = reduceMotion ? const WgMotion().reduced() : const WgMotion();
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.textSecondary,
      onSecondary: colors.canvas,
      error: colors.negative,
      onError: colors.onPrimaryFill,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.raised,
      outline: colors.hairlineStrong,
      outlineVariant: colors.hairline,
    );
    final hairlineSide = BorderSide(color: colors.hairline);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: WgFonts.ui,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      dividerColor: colors.hairline,
      focusColor: colors.accentWash,
      hoverColor: colors.raised,
      highlightColor: colors.transparent,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(size: sizes.icon, color: colors.textSecondary),
      textTheme: TextTheme(
        bodySmall: type.caption,
        bodyMedium: type.body,
        bodyLarge: type.body,
        labelMedium: type.label,
        labelLarge: type.label,
        titleSmall: type.bodyStrong,
        titleMedium: type.title,
        titleLarge: type.heading,
        headlineSmall: type.display,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.selection,
        selectionHandleColor: colors.accent,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: motion.tooltipWait,
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: radii.smAll,
          border: Border.fromBorderSide(hairlineSide),
        ),
        textStyle: type.caption.copyWith(color: colors.textPrimary),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(sizes.focusRing * 3),
        radius: Radius.circular(radii.xs),
        thumbColor: WidgetStatePropertyAll(colors.hairlineStrong),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.transparent,
        barrierColor: colors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: radii.lgAll,
          side: hairlineSide,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.transparent,
        modalBarrierColor: colors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.raised,
        contentTextStyle: type.body,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radii.mdAll,
          side: hairlineSide,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radii.mdAll,
          side: BorderSide(color: colors.hairlineStrong),
        ),
      ),
      extensions: [colors, type, const WgSpace(), radii, sizes, motion],
    );
  }
}

extension WgThemeContext on BuildContext {
  ThemeData get _theme => Theme.of(this);
  WgColors get colors => _theme.extension<WgColors>()!;
  WgType get type => _theme.extension<WgType>()!;
  WgSpace get space => _theme.extension<WgSpace>()!;
  WgRadii get radii => _theme.extension<WgRadii>()!;
  WgSizes get sizes => _theme.extension<WgSizes>()!;
  WgMotion get motion => _theme.extension<WgMotion>()!;
  bool get isDark => _theme.brightness == Brightness.dark;
}
