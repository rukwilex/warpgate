import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate_core/features/snippets/data/snippet_repository.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';

final snippetRepositoryProvider = Provider<SnippetRepository>(
  (ref) => SnippetRepository(ref.watch(documentStoreProvider)),
);

final snippetsProvider =
    AsyncNotifierProvider<SnippetsController, List<Snippet>>(
      SnippetsController.new,
    );

class SnippetsController extends AsyncNotifier<List<Snippet>> {
  static const String collection = SnippetRepository.collection;

  @override
  Future<List<Snippet>> build() => ref.watch(snippetRepositoryProvider).all();

  Future<void> reload() async =>
      state = AsyncData(await ref.read(snippetRepositoryProvider).all());

  Future<void> save({
    required String name,
    required String body,
    String? id,
  }) async {
    final snippet = await ref
        .read(snippetRepositoryProvider)
        .save(name: name, body: body, id: id);
    final rest = (state.value ?? const []).where(
      (item) => item.id != snippet.id,
    );
    state = AsyncData(
      [...rest, snippet]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );
  }

  Future<void> delete(String id) async {
    await ref.read(snippetRepositoryProvider).delete(id);
    state = AsyncData(
      (state.value ?? const []).where((item) => item.id != id).toList(),
    );
  }
}
