import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class HostRepository {
  new(this._store, this._secrets);

  static const hostsCollection = 'hosts';
  static const groupsCollection = 'host_groups';
  static const knownHostsCollection = 'known_hosts';

  final DocumentStore _store;
  final SecretStore _secrets;

  Future<List<Host>> hosts() async => [
    for (final json in await _store.all(hostsCollection)) Host.fromJson(json),
  ];

  Future<void> saveHost(Host host) =>
      _store.put(hostsCollection, host.id, host.toJson());

  Future<void> deleteHost(String id) async {
    await _store.delete(hostsCollection, id);
    await _secrets.delete(SecretKeys.hostPassword(id));
  }

  Future<String?> password(String hostId) =>
      _secrets.read(SecretKeys.hostPassword(hostId));

  Future<void> setPassword(String hostId, String? password) =>
      password == null || password.isEmpty
      ? _secrets.delete(SecretKeys.hostPassword(hostId))
      : _secrets.write(SecretKeys.hostPassword(hostId), password);

  Future<List<HostGroup>> groups() async => [
    for (final json in await _store.all(groupsCollection))
      HostGroup.fromJson(json),
  ];

  Future<void> saveGroup(HostGroup group) =>
      _store.put(groupsCollection, group.id, group.toJson());

  Future<void> deleteGroup(String id) => _store.delete(groupsCollection, id);

  Future<KnownHost?> knownHost(String endpoint) async {
    final json = await _store.get(knownHostsCollection, endpoint);
    return json == null ? null : KnownHost.fromJson(json);
  }

  Future<List<KnownHost>> knownHosts() async => [
    for (final json in await _store.all(knownHostsCollection))
      KnownHost.fromJson(json),
  ];

  Future<void> trust(KnownHost host) =>
      _store.put(knownHostsCollection, host.endpoint, host.toJson());

  Future<void> forget(String endpoint) =>
      _store.delete(knownHostsCollection, endpoint);
}
