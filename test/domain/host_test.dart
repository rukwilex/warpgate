import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/hosts/domain/ssh_config_parser.dart';

void main() {
  test('host json round trip', () {
    const host = Host(
      id: '1',
      label: 'db',
      address: '10.0.0.5',
      username: 'ops',
      port: 2200,
      auth: AuthMethod.key,
      keyId: 'k',
      tags: ['db', 'eu'],
      tmuxPersistence: true,
      mcpPermission: McpPermission.readOnly,
      forwards: [
        PortForwardSpec(
          id: 'f',
          kind: ForwardKind.local,
          bindPort: 5432,
          targetHost: 'localhost',
          targetPort: 5432,
        ),
      ],
    );
    expect(Host.fromJson(host.toJson()), host);
    expect(host.endpoint, 'ops@10.0.0.5:2200');
  });

  test('jump chains resolve in order and detect cycles', () {
    const a = Host(id: 'a', label: 'a', address: 'a', username: 'u');
    const b = Host(
      id: 'b',
      label: 'b',
      address: 'b',
      username: 'u',
      jumpHostId: 'a',
    );
    const c = Host(
      id: 'c',
      label: 'c',
      address: 'c',
      username: 'u',
      jumpHostId: 'b',
    );
    final byId = {'a': a, 'b': b, 'c': c};
    expect(HostChain.resolve(c, byId).map((h) => h.id), ['a', 'b', 'c']);
    expect(HostChain.wouldCycle('a', 'c', byId), isTrue);
    expect(HostChain.wouldCycle('c', 'a', byId), isFalse);
  });

  test('ssh config parser reads hosts, globals and skips patterns', () {
    const config = '''
Host *
  User admin
  ServerAliveInterval 30

Host bastion
  HostName 203.0.113.10
  Port 2222

Host app-1 app-2
  HostName 10.0.1.5
  ProxyJump bastion
  IdentityFile ~/.ssh/id_ed25519

Host *.internal
  User nobody

Match host foo
  User ignored
''';
    final entries = SshConfigParser.parse(config);
    expect(entries.map((e) => e.alias), ['bastion', 'app-1', 'app-2']);
    expect(entries.first.port, 2222);
    expect(entries.first.user, 'admin');
    expect(entries[1].proxyJump, 'bastion');
    expect(entries[1].identityFile, '~/.ssh/id_ed25519');
  });
}
