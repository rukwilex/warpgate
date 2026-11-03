import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';

@immutable
class FilePlaces {
  const new({this.favorites = const [], this.recents = const []});

  factory fromJson(JsonMap json) => FilePlaces(
    favorites: ((json['favorites'] as List?) ?? const <Object?>[])
        .cast<String>(),
    recents: ((json['recents'] as List?) ?? const <Object?>[]).cast<String>(),
  );

  static const maxRecents = 12;

  final List<String> favorites;
  final List<String> recents;

  JsonMap toJson() => {'favorites': favorites, 'recents': recents};
}

String placesKey(String? hostId) => hostId ?? 'local';

final filePlacesProvider =
    NotifierProvider<FilePlacesController, Map<String, FilePlaces>>(
      FilePlacesController.new,
    );

class FilePlacesController extends Notifier<Map<String, FilePlaces>> {
  static const collection = 'file_places';

  @override
  Map<String, FilePlaces> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    final docs = await ref.read(documentStoreProvider).all(collection);
    if (!ref.mounted) return;
    state = {
      for (final json in docs)
        json['key']! as String: FilePlaces.fromJson(json),
      ...state,
    };
  }

  FilePlaces of(String? hostId) =>
      state[placesKey(hostId)] ?? const FilePlaces();

  void _set(String? hostId, FilePlaces places) {
    final key = placesKey(hostId);
    state = {...state, key: places};
    unawaited(
      ref.read(documentStoreProvider).put(collection, key, {
        'key': key,
        ...places.toJson(),
      }),
    );
  }

  bool isFavorite(String? hostId, String path) =>
      of(hostId).favorites.contains(path);

  void toggleFavorite(String? hostId, String path) {
    final current = of(hostId);
    final favorites = current.favorites.contains(path)
        ? [...current.favorites.where((item) => item != path)]
        : [...current.favorites, path];
    _set(hostId, FilePlaces(favorites: favorites, recents: current.recents));
  }

  void visit(String? hostId, String path) {
    final current = of(hostId);
    if (current.recents.isNotEmpty && current.recents.first == path) return;
    final recents = [
      path,
      ...current.recents.where((item) => item != path),
    ].take(FilePlaces.maxRecents).toList();
    _set(hostId, FilePlaces(favorites: current.favorites, recents: recents));
  }
}

@immutable
class FileClipboard {
  const new({required this.hostId, required this.entries, required this.cut});

  final String? hostId;
  final List<FileEntry> entries;
  final bool cut;
}

final fileClipboardProvider =
    NotifierProvider<FileClipboardController, FileClipboard?>(
      FileClipboardController.new,
    );

class FileClipboardController extends Notifier<FileClipboard?> {
  @override
  FileClipboard? build() => null;

  void put(String? hostId, List<FileEntry> entries, {required bool cut}) {
    if (entries.isEmpty) return;
    state = FileClipboard(hostId: hostId, entries: entries, cut: cut);
  }

  void clear() => state = null;
}

enum HostOpenMode {
  terminal('Terminal'),
  files('Files'),
  both('Terminal + Files');

  new(this.label);

  final String label;
}
