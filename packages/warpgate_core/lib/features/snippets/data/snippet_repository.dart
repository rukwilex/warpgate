import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';

class SnippetRepository {
  new(this._store);

  static const collection = 'snippets';

  final DocumentStore _store;

  Future<List<Snippet>> all() async {
    final docs = await _store.all(collection);
    return [for (final json in docs) Snippet.fromJson(json)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Snippet> save({
    required String name,
    required String body,
    String? id,
  }) async {
    final snippet = Snippet(
      id: id ?? Ids.next(),
      name: name.trim(),
      body: body,
    );
    await _store.put(collection, snippet.id, snippet.toJson());
    return snippet;
  }

  Future<void> delete(String id) => _store.delete(collection, id);
}
