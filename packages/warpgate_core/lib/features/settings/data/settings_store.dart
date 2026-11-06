import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

class SettingField {
  const new(this.key, this.type, {this.choices = const []});

  final String key;
  final String type;
  final List<String> choices;
}

class SettingValueError implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

class SettingsStore {
  new(this._store);

  static const collection = 'settings';
  static const documentId = 'app';

  static List<String> _names(List<Enum> values) => [
    for (final value in values) value.name,
  ];

  static final fields = <SettingField>[
    SettingField('themeMode', 'choice', choices: _names(AppThemeMode.values)),
    SettingField('accent', 'choice', choices: _names(WgAccent.values)),
    SettingField(
      'terminalScheme',
      'choice',
      choices: _names(WgTerminalScheme.values),
    ),
    const SettingField('terminalFontSize', 'number'),
    SettingField('density', 'choice', choices: _names(WgDensity.values)),
    const SettingField('scrollbackLines', 'integer'),
    const SettingField('memorySoftLimitMb', 'integer'),
    const SettingField('sshEngine', 'choice', choices: ['native', 'dart']),
    SettingField('cursorShape', 'choice', choices: _names(CursorShape.values)),
    SettingField('bell', 'choice', choices: _names(BellMode.values)),
    const SettingField('copyOnSelect', 'boolean'),
    const SettingField('confirmMultilinePaste', 'boolean'),
    const SettingField('restoreOnLaunch', 'boolean'),
    const SettingField('autoReconnect', 'boolean'),
    const SettingField('tmuxByDefault', 'boolean'),
    const SettingField('persistScrollback', 'boolean'),
    const SettingField('persistedScrollbackLines', 'integer'),
    const SettingField('transferConcurrency', 'integer'),
    SettingField(
      'conflictPolicy',
      'choice',
      choices: _names(ConflictPolicy.values),
    ),
    const SettingField('offerDirectMode', 'boolean'),
    const SettingField('defaultLocalPath', 'string'),
    const SettingField('defaultRemotePath', 'string'),
    const SettingField('showHiddenFiles', 'boolean'),
    const SettingField('biometricUnlock', 'boolean'),
    const SettingField('autoLockMinutes', 'integer'),
    const SettingField('clipboardClearSeconds', 'integer'),
    const SettingField('mcpEnabled', 'boolean'),
    const SettingField('mcpPort', 'integer'),
    const SettingField('mcpAskBeforeMutating', 'boolean'),
    const SettingField('sidebarCollapsed', 'boolean'),
  ];

  final DocumentStore _store;

  Future<AppSettings> load() async {
    final json = await _store.get(collection, documentId);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  Future<void> save(AppSettings settings) =>
      _store.put(collection, documentId, settings.toJson());

  Future<AppSettings> patch(JsonMap changes) => _store.transaction(() async {
    final next = (await load()).patch(changes);
    await save(next);
    return next;
  });

  static SettingField field(String key) => fields.firstWhere(
    (field) => field.key == key,
    orElse: () => throw SettingValueError(
      'There is no setting called "$key". Run warpgate settings list',
    ),
  );

  static Object? coerce(String key, String raw) {
    final setting = field(key);
    switch (setting.type) {
      case 'boolean':
        if (raw == 'true') return true;
        if (raw == 'false') return false;
        throw SettingValueError('$key must be true or false');
      case 'integer':
        return int.tryParse(raw) ??
            (throw SettingValueError('$key must be a whole number'));
      case 'number':
        return num.tryParse(raw)?.toDouble() ??
            (throw SettingValueError('$key must be a number'));
      case 'choice':
        if (setting.choices.contains(raw)) return raw;
        throw SettingValueError(
          '$key must be one of: ${setting.choices.join(', ')}',
        );
      default:
        return raw;
    }
  }
}
