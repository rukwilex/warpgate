import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/settings/domain/app_settings.dart';

final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  static const collection = 'settings';
  static const documentId = 'app';

  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  static Future<AppSettings> load(DocumentStore store) async {
    final json = await store.get(collection, documentId);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  void update(JsonMap changes) {
    state = state.patch(changes);
    unawaited(
      ref
          .read(documentStoreProvider)
          .put(collection, documentId, state.toJson()),
    );
  }

  void replace(AppSettings value) {
    state = value;
    unawaited(
      ref
          .read(documentStoreProvider)
          .put(collection, documentId, state.toJson()),
    );
  }
}
