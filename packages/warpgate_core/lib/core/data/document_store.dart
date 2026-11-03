typedef JsonMap = Map<String, Object?>;

abstract interface class DocumentStore {
  Future<List<JsonMap>> all(
    String collection, {
    bool newestFirst = false,
    int? limit,
  });

  Future<JsonMap?> get(String collection, String id);

  Future<void> put(String collection, String id, JsonMap body, {DateTime? at});

  Future<void> putAll(String collection, Map<String, JsonMap> bodies);

  Future<void> delete(String collection, String id);

  Future<void> clear(String collection);

  Future<void> trim(String collection, int keep);

  Future<T> transaction<T>(Future<T> Function() body);

  Future<int> dataVersion();
}
