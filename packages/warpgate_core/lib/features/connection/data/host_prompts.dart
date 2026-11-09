import 'dart:async';

import 'package:dartssh2/dartssh2.dart' show SSHUserInfoRequest;
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class HostPrompts {
  HostPrompts(this._hosts, this._broker);

  final HostRepository _hosts;
  final InteractionBroker _broker;
  final Map<String, Future<void>> _locks = {};

  Future<T> serial<T>(String hostId, Future<T> Function() prompt) async {
    while (_locks[hostId] != null) {
      await _locks[hostId];
    }
    final completer = Completer<void>();
    _locks[hostId] = completer.future;
    try {
      return await prompt();
    } finally {
      _locks.remove(hostId)?.ignore();
      completer.complete();
    }
  }

  Future<String?> ask(String hostId, SecretRequest request) => serial(hostId, () => _broker.ask(request));

  Future<String?> password(Host host) async {
    final stored = await _hosts.password(host.id);
    if (stored != null) return stored;
    final request = SecretRequest(
      title: 'Password for ${host.label}',
      message: host.endpoint,
      fieldLabel: 'Password',
      allowRemember: true,
    );
    final value = await ask(host.id, request);
    if (value != null && request.remember) {
      await _hosts.setPassword(host.id, value);
    }
    return value;
  }

  Future<List<String>?> keyboardInteractive(Host host, SSHUserInfoRequest request) async {
    final answers = <String>[];
    for (final prompt in request.prompts) {
      if (prompt.promptText.toLowerCase().contains('password')) {
        final stored = await _hosts.password(host.id);
        if (stored != null) {
          answers.add(stored);
          continue;
        }
      }
      final value = await ask(
        host.id,
        SecretRequest(
          title: request.name.isEmpty ? 'Sign in to ${host.label}' : request.name,
          message: request.instruction.isEmpty ? host.endpoint : request.instruction,
          fieldLabel: prompt.promptText.trim().replaceAll(RegExp(r':$'), ''),
        ),
      );
      if (value == null) return null;
      answers.add(value);
    }
    return answers;
  }

  Future<bool> verifyHostKey(Host host, String type, String fingerprint) async {
    final known = await _hosts.knownHost(host.knownHostsKey);
    if (known != null && known.fingerprint == fingerprint) return true;
    final verdict = await serial(
      host.id,
      () => _broker.ask(
        HostKeyRequest(
          hostLabel: host.label,
          endpoint: host.knownHostsKey,
          keyType: type,
          fingerprint: fingerprint,
          previousFingerprint: known?.fingerprint,
        ),
      ),
    );
    switch (verdict) {
      case HostKeyVerdict.reject:
        return false;
      case HostKeyVerdict.trustOnce:
        return true;
      case HostKeyVerdict.trustAndSave:
        await _hosts.trust(
          KnownHost(endpoint: host.knownHostsKey, keyType: type, fingerprint: fingerprint, addedAt: DateTime.now()),
        );
        return true;
    }
  }

  bool usesPassword(Host host) => host.auth == AuthMethod.password || host.auth == AuthMethod.agent;
}
