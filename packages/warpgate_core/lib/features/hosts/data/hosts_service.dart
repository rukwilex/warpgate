import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/hosts/domain/ssh_config_parser.dart';

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

class HostsService {
  new(this.repository);

  final HostRepository repository;

  HostsCatalog _catalog = const HostsCatalog();

  HostsCatalog get catalog => _catalog;

  static int _byLabel(Host a, Host b) =>
      a.label.toLowerCase().compareTo(b.label.toLowerCase());

  Future<HostsCatalog> load() async {
    final hosts = await repository.hosts();
    final groups = await repository.groups();
    hosts.sort(_byLabel);
    groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _catalog = HostsCatalog(hosts: hosts, groups: groups);
  }

  Future<void> saveHost(
    Host host, {
    String? password,
    bool clearPassword = false,
  }) async {
    await repository.saveHost(host);
    if (password != null && password.isNotEmpty) {
      await repository.setPassword(host.id, password);
    } else if (clearPassword) {
      await repository.setPassword(host.id, null);
    }
    final hosts = [..._catalog.hosts.where((item) => item.id != host.id), host]
      ..sort(_byLabel);
    _catalog = HostsCatalog(hosts: hosts, groups: _catalog.groups);
  }

  Future<void> deleteHost(String id) async {
    await repository.deleteHost(id);
    final before = _catalog;
    final hosts = [
      for (final host in before.hosts)
        if (host.id != id)
          if (host.jumpHostId == id)
            host.copyWith(jumpHostId: () => null)
          else
            host,
    ];
    for (final host in hosts.where(
      (host) => before.host(host.id)?.jumpHostId == id,
    )) {
      await repository.saveHost(host);
    }
    _catalog = HostsCatalog(hosts: hosts, groups: before.groups);
  }

  Future<HostGroup> addGroup(String name) async {
    final group = HostGroup(id: Ids.next(), name: name.trim());
    await repository.saveGroup(group);
    _catalog = HostsCatalog(
      hosts: _catalog.hosts,
      groups: [..._catalog.groups, group],
    );
    return group;
  }

  Future<void> renameGroup(String id, String name) async {
    final group = HostGroup(id: id, name: name.trim());
    await repository.saveGroup(group);
    _catalog = HostsCatalog(
      hosts: _catalog.hosts,
      groups: [
        for (final item in _catalog.groups)
          if (item.id == id) group else item,
      ],
    );
  }

  Future<void> deleteGroup(String id) async {
    await repository.deleteGroup(id);
    final hosts = <Host>[];
    for (final host in _catalog.hosts) {
      if (host.groupId == id) {
        final moved = host.copyWith(groupId: () => null);
        await repository.saveHost(moved);
        hosts.add(moved);
      } else {
        hosts.add(host);
      }
    }
    _catalog = HostsCatalog(
      hosts: hosts,
      groups: _catalog.groups.where((group) => group.id != id).toList(),
    );
  }

  Future<int> importSshConfig(String source) async {
    final entries = SshConfigParser.parse(source);
    final existing = {for (final host in _catalog.hosts) host.label};
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
      for (final host in _catalog.hosts) host.label: host,
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
