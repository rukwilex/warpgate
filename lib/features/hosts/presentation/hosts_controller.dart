import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

export 'package:warpgate_core/features/hosts/data/hosts_service.dart'
    show HostsCatalog;

final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepository(
    ref.watch(documentStoreProvider),
    ref.watch(secretStoreProvider),
  ),
);

final hostsServiceProvider = Provider<HostsService>(
  (ref) => HostsService(ref.watch(hostRepositoryProvider)),
);

final hostsProvider = AsyncNotifierProvider<HostsController, HostsCatalog>(
  HostsController.new,
);

class HostsController extends AsyncNotifier<HostsCatalog> {
  HostsService get _service => ref.read(hostsServiceProvider);

  @override
  Future<HostsCatalog> build() => ref.watch(hostsServiceProvider).load();

  void _publish() => state = AsyncData(_service.catalog);

  Future<void> reload() async {
    await _service.load();
    _publish();
  }

  Future<void> saveHost(
    Host host, {
    String? password,
    bool clearPassword = false,
  }) async {
    await _service.saveHost(
      host,
      password: password,
      clearPassword: clearPassword,
    );
    _publish();
  }

  Future<void> deleteHost(String id) async {
    await _service.deleteHost(id);
    _publish();
  }

  Future<HostGroup> addGroup(String name) async {
    final group = await _service.addGroup(name);
    _publish();
    return group;
  }

  Future<void> renameGroup(String id, String name) async {
    await _service.renameGroup(id, name);
    _publish();
  }

  Future<void> deleteGroup(String id) async {
    await _service.deleteGroup(id);
    _publish();
  }

  Future<int> importSshConfig(String source) async {
    final count = await _service.importSshConfig(source);
    _publish();
    return count;
  }
}

final hostLookupProvider = Provider<Host? Function(String id)>(
  (ref) =>
      (id) => ref.read(hostsProvider).value?.host(id),
);

void unawaitedSave(Future<void> future) => unawaited(future);
