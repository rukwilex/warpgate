import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsOptionLists {
  static List<(WgAccent, String)> accents() => [
    for (final accent in WgAccent.values) (accent, accent.label),
  ];

  static List<(WgTerminalScheme, String)> terminalSchemes() => [
    for (final scheme in WgTerminalScheme.values) (scheme, scheme.label),
  ];

  static List<(CursorShape, String)> cursorShapes() => [
    for (final c in CursorShape.values) (c, c.label),
  ];

  static List<(BellMode, String)> bellModes() => [
    for (final b in BellMode.values) (b, b.label),
  ];

  static List<(ConflictPolicy, String)> conflictPolicies() => [
    for (final p in ConflictPolicy.values) (p, p.label),
  ];
}
