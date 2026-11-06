import 'package:meta/meta.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/settings/domain/appearance.dart';

export 'package:warpgate_core/features/settings/domain/appearance.dart';

enum CursorShape {
  block('Block'),
  underline('Underline'),
  bar('Bar');

  new(this.label);

  final String label;
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
    this.themeMode = AppThemeMode.system,
    this.accent = WgAccent.amber,
    this.terminalScheme = WgTerminalScheme.followApp,
    this.terminalFontSize = 13,
    this.density = WgDensity.comfortable,
    this.scrollbackLines = 10000,
    this.memorySoftLimitMb = 1536,
    this.sshEngine = 'native',
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
    this.hostOpenModes = const {},
    this.fileColumnWidths = const {},
    this.collapsedHostGroups = const [],
  });

  factory fromJson(JsonMap json) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((value) => value.name == json[key]).firstOrNull ??
        fallback;
    return AppSettings(
      themeMode: pick(AppThemeMode.values, 'themeMode', d.themeMode),
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
      memorySoftLimitMb: json['memorySoftLimitMb'] as int? ?? d.memorySoftLimitMb,
      sshEngine: json['sshEngine'] as String? ?? d.sshEngine,
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
      hostOpenModes:
          (json['hostOpenModes'] as Map?)?.cast<String, String>() ?? const {},
      fileColumnWidths:
          (json['fileColumnWidths'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toDouble()),
          ) ??
          const {},
      collapsedHostGroups:
          ((json['collapsedHostGroups'] as List?) ?? const <Object?>[])
              .cast<String>(),
    );
  }

  final AppThemeMode themeMode;
  final WgAccent accent;
  final WgTerminalScheme terminalScheme;
  final double terminalFontSize;
  final WgDensity density;
  final int scrollbackLines;
  final int memorySoftLimitMb;
  final String sshEngine;
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
  final Map<String, String> hostOpenModes;
  final Map<String, double> fileColumnWidths;
  final List<String> collapsedHostGroups;

  JsonMap toJson() => {
    'themeMode': themeMode.name,
    'accent': accent.name,
    'terminalScheme': terminalScheme.name,
    'terminalFontSize': terminalFontSize,
    'density': density.name,
    'scrollbackLines': scrollbackLines,
    'memorySoftLimitMb': memorySoftLimitMb,
    'sshEngine': sshEngine,
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
    'hostOpenModes': hostOpenModes,
    'fileColumnWidths': fileColumnWidths,
    'collapsedHostGroups': collapsedHostGroups,
  };

  AppSettings patch(JsonMap changes) =>
      AppSettings.fromJson({...toJson(), ...changes});
}
