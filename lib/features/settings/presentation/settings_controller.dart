import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/settings/presentation/settings_constants.dart';
import 'package:warpgate_core/features/settings/data/settings_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';

final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  static const String collection = SettingsStore.collection;
  static const String documentId = SettingsStore.documentId;

  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  static Future<AppSettings> load(DocumentStore store) =>
      SettingsStore(store).load();

  Future<void> reload() async =>
      state = await load(ref.read(documentStoreProvider));

  void update(JsonMap changes) {
    state = state.patch(changes);
    unawaited(
      ref
          .read(documentStoreProvider)
          .put(collection, documentId, state.toJson()),
    );
  }

  void setShortcut(String commandId, String binding) => update({
    SettingsKeys.shortcutOverrides: {
      ...state.shortcutOverrides,
      commandId: binding,
    },
  });

  void resetShortcut(String commandId) => update({
    SettingsKeys.shortcutOverrides: {...state.shortcutOverrides}
      ..remove(commandId),
  });

  void replace(AppSettings value) {
    state = value;
    unawaited(
      ref
          .read(documentStoreProvider)
          .put(collection, documentId, state.toJson()),
    );
  }
}
