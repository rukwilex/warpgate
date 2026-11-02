import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/util/ids.dart';
import 'package:warpgate/features/hosts/data/host_repository.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/hosts/domain/ssh_config_parser.dart';

@immutable
class HostsCatalog {
  const new({this.hosts = const [], this.groups = const []});

  final List<Host> hosts;
  final List<HostGroup> groups;

  Map<String, Host> get byId => {for (final host in hosts) host.id: host};

  Host? host(String? id) =>
      id == null ? null : hosts.firstWhereOrNull((host) => host.id == id);

  HostGroup? group(String? id) =>
      id == null ? null : groups.firstWhereOrNull((group) => group.id == id);

  List<Host> inGroup(String groupId) =>
      hosts.where((host) => host.groupId == groupId).toList();

  List<Host> withTag(String tag) =>
      hosts.where((host) => host.tags.contains(tag)).toList();

  List<String> get tags => hosts.expand((host) => host.tags).toSet().sorted();

  List<Host> get ungrouped => hosts
      .where((host) => host.groupId == null || group(host.groupId) == null)
      .toList();
}

final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepository(
    ref.watch(documentStoreProvider),
    ref.watch(secretStoreProvider),
  ),
);

final hostsProvider = AsyncNotifierProvider<HostsController, HostsCatalog>(
  HostsController.new,
);

class HostsController extends AsyncNotifier<HostsCatalog> {
  HostRepository get _repo => ref.read(hostRepositoryProvider);

  @override
  Future<HostsCatalog> build() async {
    final repo = ref.watch(hostRepositoryProvider);
    final hosts = await repo.hosts();
    final groups = await repo.groups();
    hosts.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return HostsCatalog(hosts: hosts, groups: groups);
  }

  HostsCatalog get _current => state.value ?? const HostsCatalog();

  Future<void> saveHost(
    Host host, {
    String? password,
    bool clearPassword = false,
  }) async {
    await _repo.saveHost(host);
    if (password != null && password.isNotEmpty) {
      await _repo.setPassword(host.id, password);
    } else if (clearPassword) {
      await _repo.setPassword(host.id, null);
    }
    final hosts = [..._current.hosts.where((item) => item.id != host.id), host]
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    state = AsyncData(HostsCatalog(hosts: hosts, groups: _current.groups));
  }

  Future<void> deleteHost(String id) async {
    await _repo.deleteHost(id);
    final hosts = [
      for (final host in _current.hosts)
        if (host.id != id)
          if (host.jumpHostId == id)
            host.copyWith(jumpHostId: () => null)
          else
            host,
    ];
    for (final host in hosts.where(
      (host) => _current.host(host.id)?.jumpHostId == id,
    )) {
      await _repo.saveHost(host);
    }
    state = AsyncData(HostsCatalog(hosts: hosts, groups: _current.groups));
  }

  Future<HostGroup> addGroup(String name) async {
    final group = HostGroup(id: Ids.next(), name: name.trim());
    await _repo.saveGroup(group);
    state = AsyncData(
      HostsCatalog(hosts: _current.hosts, groups: [..._current.groups, group]),
    );
    return group;
  }

  Future<void> renameGroup(String id, String name) async {
    final group = HostGroup(id: id, name: name.trim());
    await _repo.saveGroup(group);
    state = AsyncData(
      HostsCatalog(
        hosts: _current.hosts,
        groups: [
          for (final item in _current.groups)
            if (item.id == id) group else item,
        ],
      ),
    );
  }

  Future<void> deleteGroup(String id) async {
    await _repo.deleteGroup(id);
    final hosts = <Host>[];
    for (final host in _current.hosts) {
      if (host.groupId == id) {
        final moved = host.copyWith(groupId: () => null);
        await _repo.saveHost(moved);
        hosts.add(moved);
      } else {
        hosts.add(host);
      }
    }
    state = AsyncData(
      HostsCatalog(
        hosts: hosts,
        groups: _current.groups.where((g) => g.id != id).toList(),
      ),
    );
  }

  Future<int> importSshConfig(String source) async {
    final entries = SshConfigParser.parse(source);
    final existing = {for (final host in _current.hosts) host.label};
    final created = <String, Host>{};
    for (final entry in entries) {
      if (existing.contains(entry.alias)) continue;
      created[entry.alias] = Host(
        id: Ids.next(),
        label: entry.alias,
        address: entry.hostName,
        port: entry.port,
        username: entry.user ?? 'root',
        auth: entry.identityFile == null ? AuthMethod.password : AuthMethod.key,
      );
    }
    final byLabel = {
      for (final host in _current.hosts) host.label: host,
      ...created,
    };
    for (final entry in entries) {
      final host = created[entry.alias];
      final jump = entry.proxyJump?.split(',').first.trim();
      if (host == null || jump == null) continue;
      final jumpHost = byLabel[jump];
      if (jumpHost != null) {
        created[entry.alias] = host.copyWith(jumpHostId: () => jumpHost.id);
      }
    }
    for (final host in created.values) {
      await saveHost(host);
    }
    return created.length;
  }
}

final hostLookupProvider = Provider<Host? Function(String id)>(
  (ref) =>
      (id) => ref.read(hostsProvider).value?.host(id),
);

void unawaitedSave(Future<void> future) => unawaited(future);
