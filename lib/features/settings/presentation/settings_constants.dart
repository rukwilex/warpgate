import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsKeys {
  static const String themeMode = 'themeMode';
  static const String accent = 'accent';
  static const String terminalScheme = 'terminalScheme';
  static const String terminalFontSize = 'terminalFontSize';
  static const String density = 'density';
  static const String scrollbackLines = 'scrollbackLines';
  static const String cursorShape = 'cursorShape';
  static const String bell = 'bell';
  static const String copyOnSelect = 'copyOnSelect';
  static const String confirmMultilinePaste = 'confirmMultilinePaste';
  static const String restoreOnLaunch = 'restoreOnLaunch';
  static const String autoReconnect = 'autoReconnect';
  static const String persistScrollback = 'persistScrollback';
  static const String tmuxByDefault = 'tmuxByDefault';
  static const String transferConcurrency = 'transferConcurrency';
  static const String conflictPolicy = 'conflictPolicy';
  static const String offerDirectMode = 'offerDirectMode';
  static const String showHiddenFiles = 'showHiddenFiles';
  static const String defaultRemotePath = 'defaultRemotePath';
  static const String defaultLocalPath = 'defaultLocalPath';
  static const String appLock = 'appLock';
  static const String biometricUnlock = 'biometricUnlock';
  static const String autoLockMinutes = 'autoLockMinutes';
  static const String clipboardClearSeconds = 'clipboardClearSeconds';
  static const String mcpEnabled = 'mcpEnabled';
  static const String mcpPort = 'mcpPort';
  static const String mcpAskBeforeMutating = 'mcpAskBeforeMutating';
  static const String sshEngine = 'sshEngine';
  static const String memorySoftLimitMb = 'memorySoftLimitMb';
  static const String shortcutOverrides = 'shortcutOverrides';
}

abstract final class SettingsSectionIds {
  static const String appearance = 'appearance';
  static const String terminal = 'terminal';
  static const String sessions = 'sessions';
  static const String files = 'files';
  static const String shortcuts = 'shortcuts';
  static const String security = 'security';
  static const String integrations = 'integrations';
  static const String commandLine = 'command-line';
  static const String backup = 'backup';
  static const String diagnostics = 'diagnostics';
  static const String about = 'about';
}

abstract final class SettingsLimits {
  static const int scrollbackMin = 1000;
  static const int scrollbackMax = 100000;
  static const int scrollbackStep = 1000;
  static const int transfersMin = 1;
  static const int transfersMax = 16;
  static const int memoryLimitMinMb = 512;
  static const int memoryLimitMaxMb = 8192;
  static const int memoryLimitStepMb = 256;
  static const int portMin = 1024;
  static const int portMax = 65535;
  static const int pinMinLength = 4;
  static const int pinMaxLength = 12;
  static const int passphraseMinLength = 8;
  static const int tokenMaskMinLength = 8;
  static const int tokenVisibleChars = 4;
  static const int tokenMaskDots = 12;
}

abstract final class SettingsDefaults {
  static const String homePath = '~';
  static const String appVersion = '1.0.0';
  static const String applicationName = 'Warpgate';
}

abstract final class SettingsOptions {
  static const List<(AppThemeMode, String)> themeMode = [
    (AppThemeMode.system, 'System'),
    (AppThemeMode.dark, 'Dark'),
    (AppThemeMode.light, 'Light'),
  ];

  static const List<(WgDensity, String)> density = [
    (WgDensity.compact, 'Compact'),
    (WgDensity.comfortable, 'Comfortable'),
  ];

  static const List<(int, String)> autoLockMinutes = [
    (1, '1 min'),
    (5, '5 min'),
    (15, '15 min'),
    (60, '1 hour'),
  ];

  static const List<(int, String)> clipboardClearSeconds = [
    (15, '15 s'),
    (30, '30 s'),
    (60, '1 min'),
    (0, 'Never'),
  ];

  static const List<(String, String)> sshEngine = [
    ('native', 'Native'),
    ('dart', 'Dart'),
  ];
}
