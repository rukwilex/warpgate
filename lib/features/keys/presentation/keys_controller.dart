import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/features/keys/data/key_repository.dart';
import 'package:warpgate/features/keys/domain/ssh_key.dart';

final keyRepositoryProvider = Provider<KeyRepository>(
  (ref) => KeyRepository(
    ref.watch(documentStoreProvider),
    ref.watch(secretStoreProvider),
  ),
);

final keysProvider = AsyncNotifierProvider<KeysController, List<SshKey>>(
  KeysController.new,
);

class KeysController extends AsyncNotifier<List<SshKey>> {
  KeyRepository get _repo => ref.read(keyRepositoryProvider);

  @override
  Future<List<SshKey>> build() async {
    final keys = await ref.watch(keyRepositoryProvider).all();
    return keys
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<SshKey> get _current => state.value ?? const [];

  Future<SshKey> add({
    required String name,
    required KeyMaterial material,
    String? passphrase,
  }) async {
    final key = await _repo.save(
      name: name,
      material: material,
      passphrase: passphrase,
    );
    state = AsyncData([..._current, key]);
    return key;
  }

  Future<void> rename(SshKey key, String name) async {
    final renamed = key.rename(name);
    await _repo.update(renamed);
    state = AsyncData([
      for (final item in _current)
        if (item.id == key.id) renamed else item,
    ]);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData(_current.where((key) => key.id != id).toList());
  }

  Future<void> reload() async => state = AsyncData(await build());
}
