import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:warpgate_core/core/data/document_store.dart';

export 'package:warpgate_core/core/data/document_store.dart';

class AppDatabase extends GeneratedDatabase {
  new(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE IF NOT EXISTS documents ( '
        'collection TEXT NOT NULL, '
        'id TEXT NOT NULL, '
        'body TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL, '
        'PRIMARY KEY (collection, id))',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS documents_by_time '
        'ON documents (collection, updated_at)',
      );
    },
    beforeOpen: (_) async {
      await customSelect('PRAGMA journal_mode = WAL').get();
      await customSelect('PRAGMA busy_timeout = 5000').get();
    },
  );
}

class DriftDocumentStore implements DocumentStore {
  new(this._db);

  final AppDatabase _db;

  @override
  Future<List<JsonMap>> all(
    String collection, {
    bool newestFirst = false,
    int? limit,
  }) async {
    final order = newestFirst ? 'DESC' : 'ASC';
    final limitClause = limit == null ? '' : ' LIMIT $limit';
    final rows = await _db
        .customSelect(
          'SELECT body FROM documents WHERE collection = ? '
          'ORDER BY updated_at $order$limitClause',
          variables: [Variable.withString(collection)],
        )
        .get();
    return [for (final row in rows) _decode(row.read<String>('body'))];
  }

  @override
  Future<JsonMap?> get(String collection, String id) async {
    final row = await _db
        .customSelect(
          'SELECT body FROM documents WHERE collection = ? AND id = ?',
          variables: [Variable.withString(collection), Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _decode(row.read<String>('body'));
  }

  @override
  Future<void> put(
    String collection,
    String id,
    JsonMap body, {
    DateTime? at,
  }) => _db.customStatement(
    'INSERT OR REPLACE INTO documents (collection, id, body, updated_at) '
    'VALUES (?, ?, ?, ?)',
    [
      collection,
      id,
      jsonEncode(body),
      (at ?? DateTime.now()).microsecondsSinceEpoch,
    ],
  );

  @override
  Future<void> putAll(String collection, Map<String, JsonMap> bodies) =>
      _db.transaction(() async {
        for (final MapEntry(:key, :value) in bodies.entries) {
          await put(collection, key, value);
        }
      });

  @override
  Future<void> delete(String collection, String id) => _db.customStatement(
    'DELETE FROM documents WHERE collection = ? AND id = ?',
    [collection, id],
  );

  @override
  Future<void> clear(String collection) => _db.customStatement(
    'DELETE FROM documents WHERE collection = ?',
    [collection],
  );

  @override
  Future<void> trim(String collection, int keep) => _db.customStatement(
    'DELETE FROM documents WHERE collection = ? AND id NOT IN ( '
    'SELECT id FROM documents WHERE collection = ? '
    'ORDER BY updated_at DESC LIMIT ?)',
    [collection, collection, keep],
  );

  @override
  Future<T> transaction<T>(Future<T> Function() body) => _db.transaction(body);

  @override
  Future<int> dataVersion() async {
    final row = await _db.customSelect('PRAGMA data_version').getSingle();
    return row.read<int>('data_version');
  }

  JsonMap _decode(String body) =>
      (jsonDecode(body) as Map).cast<String, Object?>();
}
