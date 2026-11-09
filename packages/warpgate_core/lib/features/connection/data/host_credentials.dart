import 'package:dartssh2/dartssh2.dart' show SSHIdentity, SSHKeyPair;
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/host_prompts.dart';
import 'package:warpgate_core/features/connection/data/ssh_agent_client.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/engine/native/native_auth.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';

typedef UnlockedKey = ({String pem, String? passphrase});

class HostCredentials {
  new({
    required this._keys,
    required this._prompts,
    Future<List<SSHIdentity>> Function()? agentIdentities,
    this.fallbackIdentities,
    this.fallbackKeys,
  }) : _agentIdentities = agentIdentities ?? SshAgentClient.identitiesFromEnvironment;

  final KeyRepository _keys;
  final HostPrompts _prompts;
  final Future<List<SSHIdentity>> Function() _agentIdentities;
  final Future<List<SSHIdentity>> Function(Host host)? fallbackIdentities;
  final Future<List<String>> Function(Host host)? fallbackKeys;

  Future<UnlockedKey?> unlockedKey(Host host) async {
    final keyId = host.keyId;
    if (host.auth != AuthMethod.key || keyId == null) return null;
    final material = await _keys.privateMaterial(keyId);
    if (material == null) {
      throw const MissingCredentialsException('The key for this host is missing. Pick a key in the host settings');
    }
    var passphrase = material.passphrase;
    if (passphrase == null && SSHKeyPair.isEncryptedPem(material.pem)) {
      passphrase = await _prompts.ask(
        host.id,
        SecretRequest(
          title: 'Unlock key',
          message: 'The key for ${host.label} is protected with a passphrase.',
          fieldLabel: 'Passphrase',
        ),
      );
      if (passphrase == null) {
        throw const MissingCredentialsException('A passphrase is needed to use this key');
      }
    }
    return (pem: material.pem, passphrase: passphrase);
  }

  Future<List<SSHIdentity>?> identities(Host host) async {
    if (host.auth == AuthMethod.agent) {
      final fallback = fallbackIdentities;
      return [...await _agentIdentities(), if (fallback != null) ...await fallback(host)];
    }
    final key = await unlockedKey(host);
    return key == null ? null : SSHKeyPair.fromPem(key.pem, key.passphrase);
  }

  Future<List<NativeCredential>> nativeCredentials(Host host) async {
    if (host.auth == AuthMethod.agent) {
      final fallback = fallbackKeys;
      return [
        AgentCredential(SshAgentClient.location),
        if (fallback != null)
          for (final pem in await fallback(host)) KeyCredential(pem, null),
      ];
    }
    final key = await unlockedKey(host);
    return key == null ? const [] : [KeyCredential(key.pem, key.passphrase)];
  }
}
