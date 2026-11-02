import 'package:flutter/material.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/design_system/theme/wg_terminal_theme.dart';
import 'package:warpgate/design_system/tokens/wg_colors.dart';
import 'package:warpgate/design_system/tokens/wg_metrics.dart';
import 'package:xterm/xterm.dart';

enum CursorShape {
  block('Block', TerminalCursorType.block),
  underline('Underline', TerminalCursorType.underline),
  bar('Bar', TerminalCursorType.verticalBar);

  new(this.label, this.type);

  final String label;
  final TerminalCursorType type;
}

enum BellMode {
  off('Off'),
  visual('Flash the pane');

  new(this.label);

  final String label;
}

enum ConflictPolicy {
  ask('Ask each time'),
  overwrite('Overwrite'),
  skip('Skip'),
  rename('Keep both');

  new(this.label);

  final String label;
}

@immutable
class AppSettings {
  const new({
    this.themeMode = ThemeMode.system,
    this.accent = WgAccent.amber,
    this.terminalScheme = WgTerminalScheme.followApp,
    this.terminalFontSize = 13,
    this.density = WgDensity.comfortable,
    this.scrollbackLines = 10000,
    this.cursorShape = CursorShape.block,
    this.bell = BellMode.visual,
    this.copyOnSelect = false,
    this.confirmMultilinePaste = true,
    this.restoreOnLaunch = true,
    this.autoReconnect = true,
    this.tmuxByDefault = false,
    this.persistScrollback = true,
    this.persistedScrollbackLines = 2000,
    this.transferConcurrency = 3,
    this.conflictPolicy = ConflictPolicy.ask,
    this.offerDirectMode = true,
    this.defaultLocalPath,
    this.defaultRemotePath = '~',
    this.showHiddenFiles = false,
    this.appLock = false,
    this.biometricUnlock = true,
    this.autoLockMinutes = 5,
    this.clipboardClearSeconds = 30,
    this.mcpEnabled = false,
    this.mcpPort = 7823,
    this.mcpAskBeforeMutating = true,
    this.sidebarCollapsed = false,
    this.shortcutOverrides = const {},
  });

  factory fromJson(JsonMap json) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((value) => value.name == json[key]).firstOrNull ??
        fallback;
    return AppSettings(
      themeMode: pick(ThemeMode.values, 'themeMode', d.themeMode),
      accent: pick(WgAccent.values, 'accent', d.accent),
      terminalScheme: pick(
        WgTerminalScheme.values,
        'terminalScheme',
        d.terminalScheme,
      ),
      terminalFontSize:
          (json['terminalFontSize'] as num?)?.toDouble() ?? d.terminalFontSize,
      density: pick(WgDensity.values, 'density', d.density),
      scrollbackLines: json['scrollbackLines'] as int? ?? d.scrollbackLines,
      cursorShape: pick(CursorShape.values, 'cursorShape', d.cursorShape),
      bell: pick(BellMode.values, 'bell', d.bell),
      copyOnSelect: json['copyOnSelect'] as bool? ?? d.copyOnSelect,
      confirmMultilinePaste:
          json['confirmMultilinePaste'] as bool? ?? d.confirmMultilinePaste,
      restoreOnLaunch: json['restoreOnLaunch'] as bool? ?? d.restoreOnLaunch,
      autoReconnect: json['autoReconnect'] as bool? ?? d.autoReconnect,
      tmuxByDefault: json['tmuxByDefault'] as bool? ?? d.tmuxByDefault,
      persistScrollback:
          json['persistScrollback'] as bool? ?? d.persistScrollback,
      persistedScrollbackLines:
          json['persistedScrollbackLines'] as int? ??
          d.persistedScrollbackLines,
      transferConcurrency:
          json['transferConcurrency'] as int? ?? d.transferConcurrency,
      conflictPolicy: pick(
        ConflictPolicy.values,
        'conflictPolicy',
        d.conflictPolicy,
      ),
      offerDirectMode: json['offerDirectMode'] as bool? ?? d.offerDirectMode,
      defaultLocalPath: json['defaultLocalPath'] as String?,
      defaultRemotePath:
          json['defaultRemotePath'] as String? ?? d.defaultRemotePath,
      showHiddenFiles: json['showHiddenFiles'] as bool? ?? d.showHiddenFiles,
      appLock: json['appLock'] as bool? ?? d.appLock,
      biometricUnlock: json['biometricUnlock'] as bool? ?? d.biometricUnlock,
      autoLockMinutes: json['autoLockMinutes'] as int? ?? d.autoLockMinutes,
      clipboardClearSeconds:
          json['clipboardClearSeconds'] as int? ?? d.clipboardClearSeconds,
      mcpEnabled: json['mcpEnabled'] as bool? ?? d.mcpEnabled,
      mcpPort: json['mcpPort'] as int? ?? d.mcpPort,
      mcpAskBeforeMutating:
          json['mcpAskBeforeMutating'] as bool? ?? d.mcpAskBeforeMutating,
      sidebarCollapsed: json['sidebarCollapsed'] as bool? ?? d.sidebarCollapsed,
      shortcutOverrides:
          (json['shortcutOverrides'] as Map?)?.cast<String, String>() ??
          const {},
    );
  }

  final ThemeMode themeMode;
  final WgAccent accent;
  final WgTerminalScheme terminalScheme;
  final double terminalFontSize;
  final WgDensity density;
  final int scrollbackLines;
  final CursorShape cursorShape;
  final BellMode bell;
  final bool copyOnSelect;
  final bool confirmMultilinePaste;
  final bool restoreOnLaunch;
  final bool autoReconnect;
  final bool tmuxByDefault;
  final bool persistScrollback;
  final int persistedScrollbackLines;
  final int transferConcurrency;
  final ConflictPolicy conflictPolicy;
  final bool offerDirectMode;
  final String? defaultLocalPath;
  final String defaultRemotePath;
  final bool showHiddenFiles;
  final bool appLock;
  final bool biometricUnlock;
  final int autoLockMinutes;
  final int clipboardClearSeconds;
  final bool mcpEnabled;
  final int mcpPort;
  final bool mcpAskBeforeMutating;
  final bool sidebarCollapsed;
  final Map<String, String> shortcutOverrides;

  JsonMap toJson() => {
    'themeMode': themeMode.name,
    'accent': accent.name,
    'terminalScheme': terminalScheme.name,
    'terminalFontSize': terminalFontSize,
    'density': density.name,
    'scrollbackLines': scrollbackLines,
    'cursorShape': cursorShape.name,
    'bell': bell.name,
    'copyOnSelect': copyOnSelect,
    'confirmMultilinePaste': confirmMultilinePaste,
    'restoreOnLaunch': restoreOnLaunch,
    'autoReconnect': autoReconnect,
    'tmuxByDefault': tmuxByDefault,
    'persistScrollback': persistScrollback,
    'persistedScrollbackLines': persistedScrollbackLines,
    'transferConcurrency': transferConcurrency,
    'conflictPolicy': conflictPolicy.name,
    'offerDirectMode': offerDirectMode,
    'defaultLocalPath': defaultLocalPath,
    'defaultRemotePath': defaultRemotePath,
    'showHiddenFiles': showHiddenFiles,
    'appLock': appLock,
    'biometricUnlock': biometricUnlock,
    'autoLockMinutes': autoLockMinutes,
    'clipboardClearSeconds': clipboardClearSeconds,
    'mcpEnabled': mcpEnabled,
    'mcpPort': mcpPort,
    'mcpAskBeforeMutating': mcpAskBeforeMutating,
    'sidebarCollapsed': sidebarCollapsed,
    'shortcutOverrides': shortcutOverrides,
  };

  AppSettings patch(JsonMap changes) =>
      AppSettings.fromJson({...toJson(), ...changes});
}
