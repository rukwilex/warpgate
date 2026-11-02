import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/secret_store.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final documentStoreProvider = Provider<DocumentStore>(
  (ref) => DocumentStore(ref.watch(databaseProvider)),
);

final secretStoreProvider = Provider<SecretStore>(
  (ref) => const SecureSecretStore(),
);
