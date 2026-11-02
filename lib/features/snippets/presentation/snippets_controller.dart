import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/util/ids.dart';
import 'package:warpgate/features/snippets/domain/snippet.dart';

final snippetsProvider =
    AsyncNotifierProvider<SnippetsController, List<Snippet>>(
      SnippetsController.new,
    );

class SnippetsController extends AsyncNotifier<List<Snippet>> {
  static const collection = 'snippets';

  @override
  Future<List<Snippet>> build() async {
    final docs = await ref.watch(documentStoreProvider).all(collection);
    return [for (final json in docs) Snippet.fromJson(json)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> save({
    required String name,
    required String body,
    String? id,
  }) async {
    final snippet = Snippet(
      id: id ?? Ids.next(),
      name: name.trim(),
      body: body,
    );
    await ref
        .read(documentStoreProvider)
        .put(collection, snippet.id, snippet.toJson());
    final rest = (state.value ?? const []).where(
      (item) => item.id != snippet.id,
    );
    state = AsyncData(
      [...rest, snippet]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );
  }

  Future<void> delete(String id) async {
    await ref.read(documentStoreProvider).delete(collection, id);
    state = AsyncData(
      (state.value ?? const []).where((item) => item.id != id).toList(),
    );
  }
}
