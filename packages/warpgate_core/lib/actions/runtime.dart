import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';
import 'package:warpgate_core/features/security/data/backup_service.dart';
import 'package:warpgate_core/features/settings/data/settings_store.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/snippets/data/snippet_repository.dart';

class WarpgateRuntime {
  new({
    required this.store,
    required this.secrets,
    required this.broker,
    Future<List<SSHIdentity>> Function(Host host)? fallbackIdentities,
    Future<List<SSHIdentity>> Function()? agentIdentities,
    Future<SSHSocket> Function(String host, int port)? dial,
  }) {
    hostRepository = HostRepository(store, secrets);
    hosts = HostsService(hostRepository);
    keys = KeyRepository(store, secrets);
    snippets = SnippetRepository(store);
    settings = SettingsStore(store);
    backup = BackupService(store, secrets);
    pool = ConnectionPool(
      lookup: lookup,
      hosts: hostRepository,
      keys: keys,
      broker: broker,
      fallbackIdentities: fallbackIdentities,
      agentIdentities: agentIdentities,
      dial: dial,
    );
    forwarder = PortForwarder(pool);
    endpoints = EndpointResolver(
      pool: pool,
      labelOf: (hostId) => lookup(hostId)?.label,
    );
  }

  final DocumentStore store;
  final SecretStore secrets;
  final InteractionBroker broker;
  late final HostRepository hostRepository;
  late final HostsService hosts;
  late final KeyRepository keys;
  late final SnippetRepository snippets;
  late final SettingsStore settings;
  late final BackupService backup;
  late final ConnectionPool pool;
  late final PortForwarder forwarder;
  late final EndpointResolver endpoints;
  final Map<String, Host> _adHoc = {};

  Host? lookup(String id) => _adHoc[id] ?? hosts.catalog.host(id);

  Future<void> loadCatalog() => hosts.load();

  Host host(String reference) {
    final host = HostTargets.resolve(hosts.catalog, reference);
    if (host.id.startsWith(HostTargets.adHocPrefix)) _adHoc[host.id] = host;
    return host;
  }

  List<Host> many(String targets) {
    final found = HostTargets.resolveMany(hosts.catalog, targets);
    for (final host in found) {
      if (host.id.startsWith(HostTargets.adHocPrefix)) _adHoc[host.id] = host;
    }
    return found;
  }

  void remember(Host host) => _adHoc[host.id] = host;

  Future<void> close() async {
    await forwarder.dispose();
    await pool.dispose();
  }
}

abstract final class Failures {
  static ActionFailure classify(Object error) {
    switch (error) {
      case ActionFailure():
        return error;
      case SSHHostkeyError():
        return ActionFailure(
          SshErrorText.describe(error),
          kind: ExitKind.hostKey,
          hint: 'Check the key, then run warpgate known-hosts trust <host>',
        );
      case SSHAuthError():
      case MissingCredentialsException():
      case SSHKeyDecryptError():
      case SSHKeyDecodeError():
        return ActionFailure(SshErrorText.describe(error), kind: ExitKind.auth);
      case SSHChannelOpenError():
      case SSHError():
      case TimeoutException():
        return ActionFailure(
          SshErrorText.describe(error),
          kind: ExitKind.connection,
        );
      case FileOperationException(:final message):
        return ActionFailure(
          message,
          kind: message == 'No such file or folder'
              ? ExitKind.notFound
              : ExitKind.general,
        );
      default:
        final text = SshErrorText.describe(error);
        return ActionFailure(
          text,
          kind: error.runtimeType.toString().contains('Socket')
              ? ExitKind.connection
              : ExitKind.general,
        );
    }
  }
}
