import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

abstract final class KnownHostHandlers {
  static final Map<String, ActionHandler> all = {
    'known-hosts.list': _knownList,
    'known-hosts.rm': _knownRm,
    'known-hosts.trust': _knownTrust,
  };

  static Future<JsonMap> _knownList(ActionCall call) async => {
    'known_hosts': [
      for (final host in await call.runtime.hostRepository.knownHosts())
        Json.knownHost(host),
    ],
  };

  static Future<JsonMap> _knownRm(ActionCall call) async {
    final rt = call.runtime;
    final raw = call.string('endpoint');
    final saved = HostTargets.find(rt.hosts.catalog, raw);
    final endpoint = saved?.knownHostsKey ?? raw;
    if (await rt.hostRepository.knownHost(endpoint) == null) {
      throw ActionFailure('No saved key for "$raw"', kind: ExitKind.notFound);
    }
    await rt.hostRepository.forget(endpoint);
    return {'endpoint': endpoint};
  }

  static Future<JsonMap> _knownTrust(ActionCall call) async {
    final rt = call.runtime;
    final host = rt.host(call.string('host'));
    final expected = call.maybe('fingerprint');
    String? keyType;
    String? fingerprint;
    final socket = await SSHSocket.connect(
      host.address,
      host.port,
      timeout: ActionTimeouts.hostKeyConnect,
    );
    final client = SSHClient(
      socket,
      username: host.username,
      onVerifyHostKey: (type, bytes) {
        keyType = type;
        fingerprint = utf8.decode(bytes);
        return true;
      },
    );
    try {
      await client.authenticated.timeout(ActionTimeouts.hostKeyHandshake);
    } on Object {
      if (fingerprint == null) rethrow;
    } finally {
      unawaited(client.close());
    }
    final seen = fingerprint;
    if (seen == null) {
      throw ActionFailure('${host.label} did not send a host key', kind: ExitKind.connection);
    }
    if (expected != null && expected != seen) {
      throw ActionFailure(
        'The key of ${host.label} is $seen, not $expected',
        kind: ExitKind.hostKey,
      );
    }
    final previous = await rt.hostRepository.knownHost(host.knownHostsKey);
    if (expected == null) {
      final change = previous != null && previous.fingerprint != seen
          ? ' This replaces ${previous.fingerprint}.'
          : '';
      final confirm = call.confirm;
      final accepted = !(confirm == null) && await confirm('Trust ${host.knownHostsKey}, $keyType $seen?$change');
      if (!accepted) {
        throw ActionFailure(
          'The key was not trusted',
          kind: ExitKind.hostKey,
          hint: 'Pass --fingerprint $seen to trust it without a prompt',
        );
      }
    }
    final known = KnownHost(
      endpoint: host.knownHostsKey,
      keyType: keyType ?? '',
      fingerprint: seen,
      addedAt: DateTime.now(),
    );
    await rt.hostRepository.trust(known);
    return Json.knownHost(known);
  }
}
