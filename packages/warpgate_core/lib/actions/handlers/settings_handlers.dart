import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/settings/data/settings_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

abstract final class SettingsHandlers {
  static final Map<String, ActionHandler> all = {
    'settings.list': _settingsList,
    'settings.get': _settingsGet,
    'settings.set': _settingsSet,
    'settings.reset': _settingsReset,
  };

  static JsonMap _setting(SettingField field, JsonMap values) {
    final defaults = const AppSettings().toJson();
    return {
      'key': field.key,
      'value': values[field.key],
      'default': defaults[field.key],
      'type': field.type,
      'choices': field.choices,
    };
  }

  static Future<JsonMap> _settingsList(ActionCall call) async {
    final values = (await call.runtime.settings.load()).toJson();
    return {
      'settings': [for (final field in SettingsStore.fields) _setting(field, values)],
    };
  }

  static SettingField _field(String key) {
    try {
      return SettingsStore.field(key);
    } on SettingValueError catch (error) {
      throw ActionFailure(error.message, kind: ExitKind.notFound);
    }
  }

  static Future<JsonMap> _settingsGet(ActionCall call) async {
    final field = _field(call.string('key'));
    return _setting(field, (await call.runtime.settings.load()).toJson());
  }

  static Future<JsonMap> _settingsSet(ActionCall call) async {
    final field = _field(call.string('key'));
    final Object? value;
    try {
      value = SettingsStore.coerce(field.key, call.string('value'));
    } on SettingValueError catch (error) {
      throw ActionFailure(error.message, kind: ExitKind.usage);
    }
    final next = await call.runtime.settings.patch({field.key: value});
    return _setting(field, next.toJson());
  }

  static Future<JsonMap> _settingsReset(ActionCall call) async {
    final key = call.maybe('key');
    final defaults = const AppSettings().toJson();
    if (key != null) {
      _field(key);
      await call.runtime.settings.patch({key: defaults[key]});
      return {'reset': 1};
    }
    final current = (await call.runtime.settings.load()).toJson();
    final keys = SettingsStore.fields.map((field) => field.key).toSet();
    await call.runtime.settings.patch({
      for (final MapEntry(key: name, :value) in defaults.entries)
        name: keys.contains(name) ? value : current[name],
    });
    return {'reset': keys.length};
  }
}
