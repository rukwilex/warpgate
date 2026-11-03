import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/platform/native.dart';

class SqliteFailure implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef _Open = int Function(Pointer<Uint8>, Pointer<Pointer<Void>>, int, Pointer<Void>);
typedef _OpenN = Int32 Function(Pointer<Uint8>, Pointer<Pointer<Void>>, Int32, Pointer<Void>);
typedef _Close = int Function(Pointer<Void>);
typedef _CloseN = Int32 Function(Pointer<Void>);
typedef _Busy = int Function(Pointer<Void>, int);
typedef _BusyN = Int32 Function(Pointer<Void>, Int32);
typedef _Msg = Pointer<Uint8> Function(Pointer<Void>);
typedef _Prepare = int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Pointer<Void>>, Pointer<Void>);
typedef _PrepareN = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32, Pointer<Pointer<Void>>, Pointer<Void>);
typedef _Step = int Function(Pointer<Void>);
typedef _StepN = Int32 Function(Pointer<Void>);
typedef _BindText = int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Void>);
typedef _BindTextN = Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Int32, Pointer<Void>);
typedef _BindInt = int Function(Pointer<Void>, int, int);
typedef _BindIntN = Int32 Function(Pointer<Void>, Int32, Int64);
typedef _ColText = Pointer<Uint8> Function(Pointer<Void>, int);
typedef _ColTextN = Pointer<Uint8> Function(Pointer<Void>, Int32);
typedef _ColBytes = int Function(Pointer<Void>, int);
typedef _ColBytesN = Int32 Function(Pointer<Void>, Int32);
typedef _ColInt = int Function(Pointer<Void>, int);
typedef _ColIntN = Int64 Function(Pointer<Void>, Int32);

class _Sqlite {
  new(DynamicLibrary lib)
    : open = lib.lookupFunction<_OpenN, _Open>('sqlite3_open_v2'),
      close = lib.lookupFunction<_CloseN, _Close>('sqlite3_close_v2'),
      busy = lib.lookupFunction<_BusyN, _Busy>('sqlite3_busy_timeout'),
      errmsg = lib.lookupFunction<_Msg, _Msg>('sqlite3_errmsg'),
      prepare = lib.lookupFunction<_PrepareN, _Prepare>('sqlite3_prepare_v2'),
      step = lib.lookupFunction<_StepN, _Step>('sqlite3_step'),
      finalize = lib.lookupFunction<_StepN, _Step>('sqlite3_finalize'),
      bindText = lib.lookupFunction<_BindTextN, _BindText>('sqlite3_bind_text'),
      bindInt = lib.lookupFunction<_BindIntN, _BindInt>('sqlite3_bind_int64'),
      colText = lib.lookupFunction<_ColTextN, _ColText>('sqlite3_column_text'),
      colBytes = lib.lookupFunction<_ColBytesN, _ColBytes>('sqlite3_column_bytes'),
      colInt = lib.lookupFunction<_ColIntN, _ColInt>('sqlite3_column_int64');

  final _Open open;
  final _Close close;
  final _Busy busy;
  final _Msg errmsg;
  final _Prepare prepare;
  final _Step step;
  final _Step finalize;
  final _BindText bindText;
  final _BindInt bindInt;
  final _ColText colText;
  final _ColBytes colBytes;
  final _ColInt colInt;
}

abstract final class SqliteLibrary {
  static List<String> candidates(String? executableDir) {
    final beside = executableDir;
    if (Platform.isMacOS) return ['/usr/lib/libsqlite3.dylib'];
    if (Platform.isWindows) {
      return [
        if (beside != null) p.join(beside, 'sqlite3.dll'),
        'winsqlite3.dll',
        'sqlite3.dll',
      ];
    }
    return [
      if (beside != null) p.join(beside, 'lib', 'libsqlite3.so'),
      'libsqlite3.so.0',
      'libsqlite3.so',
    ];
  }

  static DynamicLibrary open() {
    final directory = p.dirname(Platform.resolvedExecutable);
    final tried = candidates(directory);
    for (final candidate in tried) {
      try {
        return DynamicLibrary.open(candidate);
      } on ArgumentError {
        continue;
      }
    }
    throw SqliteFailure(
      'SQLite is not available. Looked for ${tried.join(', ')}',
    );
  }
}

class SqliteDocumentStore implements DocumentStore {
  SqliteDocumentStore._(this._api, this._db);

  factory open(String path) {
    final api = _Sqlite(SqliteLibrary.open());
    Directory(p.dirname(path)).createSync(recursive: true);
    const readWriteCreate = 0x2 | 0x4;
    final name = Native.cString(utf8.encode(path));
    final out = Native.malloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    final code = api.open(name, out, readWriteCreate, nullptr);
    final handle = out.value;
    Native.free(name.cast());
    Native.free(out.cast());
    final store = SqliteDocumentStore._(api, handle);
    if (code != 0) {
      throw SqliteFailure('Could not open $path: ${store._error()}');
    }
    api.busy(handle, 5000);
    store
      .._exec('PRAGMA journal_mode = WAL')
      .._exec(
        'CREATE TABLE IF NOT EXISTS documents ( '
        'collection TEXT NOT NULL, '
        'id TEXT NOT NULL, '
        'body TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL, '
        'PRIMARY KEY (collection, id))',
      )
      .._exec(
        'CREATE INDEX IF NOT EXISTS documents_by_time '
        'ON documents (collection, updated_at)',
      );
    if (store._scalar('PRAGMA user_version') == 0) {
      store._exec('PRAGMA user_version = 1');
    }
    return store;
  }

  final _Sqlite _api;
  final Pointer<Void> _db;
  bool _inTransaction = false;

  String _error() {
    final pointer = _api.errmsg(_db);
    return pointer == nullptr ? 'unknown error' : _text(pointer);
  }

  static String _text(Pointer<Uint8> pointer, [int? length]) {
    var size = length ?? 0;
    if (length == null) {
      while (pointer[size] != 0) {
        size++;
      }
    }
    return utf8.decode(
      Uint8List.fromList(pointer.asTypedList(size)),
      allowMalformed: true,
    );
  }

  List<Object?> _run<T>(
    String sql,
    List<Object> bind,
    Object? Function(Pointer<Void> statement) row,
  ) {
    final source = Native.cString(utf8.encode(sql));
    final out = Native.malloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    final prepared = _api.prepare(_db, source, -1, out, nullptr);
    final statement = out.value;
    Native.free(source.cast());
    Native.free(out.cast());
    if (prepared != 0) throw SqliteFailure(_error());
    final held = <Pointer<Uint8>>[];
    try {
      for (final (index, value) in bind.indexed) {
        if (value is int) {
          _api.bindInt(statement, index + 1, value);
        } else {
          final bytes = utf8.encode(value as String);
          final text = Native.cString(bytes);
          held.add(text);
          _api.bindText(statement, index + 1, text, bytes.length, nullptr);
        }
      }
      final rows = <Object?>[];
      while (true) {
        final code = _api.step(statement);
        if (code == 100) {
          rows.add(row(statement));
        } else if (code == 101) {
          return rows;
        } else {
          throw SqliteFailure(_error());
        }
      }
    } finally {
      _api.finalize(statement);
      held.forEach((pointer) => Native.free(pointer.cast()));
    }
  }

  void _exec(String sql, [List<Object> bind = const []]) =>
      _run<void>(sql, bind, (_) => null);

  int _scalar(String sql) =>
      _run<int>(sql, const [], (statement) => _api.colInt(statement, 0)).first!
          as int;

  JsonMap _decode(Pointer<Void> statement) {
    final text = _api.colText(statement, 0);
    final length = _api.colBytes(statement, 0);
    return (jsonDecode(_text(text, length)) as Map).cast<String, Object?>();
  }

  @override
  Future<List<JsonMap>> all(
    String collection, {
    bool newestFirst = false,
    int? limit,
  }) async {
    final order = newestFirst ? 'DESC' : 'ASC';
    final limitClause = limit == null ? '' : ' LIMIT $limit';
    return _run<JsonMap>(
      'SELECT body FROM documents WHERE collection = ? '
      'ORDER BY updated_at $order$limitClause',
      [collection],
      _decode,
    ).cast<JsonMap>();
  }

  @override
  Future<JsonMap?> get(String collection, String id) async {
    final rows = _run<JsonMap>(
      'SELECT body FROM documents WHERE collection = ? AND id = ?',
      [collection, id],
      _decode,
    );
    return rows.isEmpty ? null : rows.first! as JsonMap;
  }

  @override
  Future<void> put(
    String collection,
    String id,
    JsonMap body, {
    DateTime? at,
  }) async => _exec(
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
      transaction(() async {
        for (final MapEntry(:key, :value) in bodies.entries) {
          await put(collection, key, value);
        }
      });

  @override
  Future<void> delete(String collection, String id) async => _exec(
    'DELETE FROM documents WHERE collection = ? AND id = ?',
    [collection, id],
  );

  @override
  Future<void> clear(String collection) async =>
      _exec('DELETE FROM documents WHERE collection = ?', [collection]);

  @override
  Future<void> trim(String collection, int keep) async => _exec(
    'DELETE FROM documents WHERE collection = ? AND id NOT IN ( '
    'SELECT id FROM documents WHERE collection = ? '
    'ORDER BY updated_at DESC LIMIT ?)',
    [collection, collection, keep],
  );

  @override
  Future<T> transaction<T>(Future<T> Function() body) async {
    if (_inTransaction) return body();
    _exec('BEGIN IMMEDIATE');
    _inTransaction = true;
    try {
      final result = await body();
      _exec('COMMIT');
      return result;
    } on Object {
      _exec('ROLLBACK');
      rethrow;
    } finally {
      _inTransaction = false;
    }
  }

  @override
  Future<int> dataVersion() async => _scalar('PRAGMA data_version');

  void close() => _api.close(_db);
}
