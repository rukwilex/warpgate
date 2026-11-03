import 'package:test/test.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

const prod = Host(id: 'id-prod-1', label: 'prod', address: '10.0.0.5', username: 'deploy', groupId: 'g');
const web = Host(id: 'id-web-1', label: 'web', address: '10.0.0.6', username: 'deploy', groupId: 'g');
const catalog = HostsCatalog(hosts: [prod, web], groups: [HostGroup(id: 'g', name: 'Live')]);

void main() {
  group('PathRef', () {
    test('host:path is remote', () {
      final ref = PathRef.parse('prod:/var/log/app.log');
      expect(ref.host, 'prod');
      expect(ref.path, '/var/log/app.log');
    });
    test('a bare host means its home', () {
      expect(PathRef.parse('prod:').path, '~');
    });
    test('user@host:port:path keeps the port with the host', () {
      final ref = PathRef.parse('me@box:2222:/tmp/a');
      expect(ref.host, 'me@box:2222');
      expect(ref.path, '/tmp/a');
    });
    test('user@host:path has no port', () {
      final ref = PathRef.parse('me@box:/tmp/a');
      expect(ref.host, 'me@box');
      expect(ref.path, '/tmp/a');
    });
    test('local paths stay local', () {
      for (final value in ['/etc/hosts', './a:b', '../a:b', '~/a:b', 'plain.txt', 'dir/a:b']) {
        expect(PathRef.parse(value).isRemote, isFalse, reason: value);
      }
    });
    test('drive letters are local on Windows only', () {
      expect(PathRef.parse(r'C:\temp\a', windows: true).isRemote, isFalse);
      expect(PathRef.parse('c:/temp', windows: false).isRemote, isTrue);
    });
    test('IPv6 endpoints keep their brackets', () {
      final ref = PathRef.parse('me@[::1]:2222:/tmp');
      expect(ref.host, 'me@[::1]:2222');
      expect(ref.path, '/tmp');
    });
  });

  group('HostTargets', () {
    test('finds by id, label, case and id prefix', () {
      expect(HostTargets.resolve(catalog, 'id-prod-1'), prod);
      expect(HostTargets.resolve(catalog, 'prod'), prod);
      expect(HostTargets.resolve(catalog, 'PROD'), prod);
      expect(HostTargets.resolve(catalog, 'id-web'), web);
    });
    test('an endpoint makes an ad hoc host that uses the agent', () {
      final host = HostTargets.resolve(catalog, 'root@example.org:2200');
      expect(host.id, startsWith(HostTargets.adHocPrefix));
      expect(host.port, 2200);
      expect(host.username, 'root');
      expect(host.auth, AuthMethod.agent);
    });
    test('an endpoint that matches a saved host uses the saved one', () {
      expect(HostTargets.resolve(catalog, 'deploy@10.0.0.5'), prod);
    });
    test('an unknown name is not found', () {
      expect(
        () => HostTargets.resolve(catalog, 'nope'),
        throwsA(isA<ActionFailure>().having((f) => f.kind, 'kind', ExitKind.notFound)),
      );
    });
    test('@group, lists and duplicates', () {
      expect(HostTargets.resolveMany(catalog, '@Live'), [prod, web]);
      expect(HostTargets.resolveMany(catalog, 'prod,web,prod'), [prod, web]);
      expect(HostTargets.resolveMany(catalog, '@live,prod'), [prod, web]);
    });
    test('an unknown group is not found', () {
      expect(
        () => HostTargets.resolveMany(catalog, '@none'),
        throwsA(isA<ActionFailure>().having((f) => f.kind, 'kind', ExitKind.notFound)),
      );
    });
  });

  group('ForwardSpecs', () {
    test('local with and without a bind host', () {
      final plain = ForwardSpecs.parse('local', '8080:localhost:80');
      expect(plain.bindHost, '127.0.0.1');
      expect(plain.bindPort, 8080);
      expect(plain.targetHost, 'localhost');
      expect(plain.targetPort, 80);
      expect(ForwardSpecs.parse('local', '0.0.0.0:8080:db:5432').bindHost, '0.0.0.0');
    });
    test('dynamic', () {
      expect(ForwardSpecs.parse('dynamic', '1080').bindPort, 1080);
    });
    test('bad specs are usage errors', () {
      expect(
        () => ForwardSpecs.parse('local', '8080'),
        throwsA(isA<ActionFailure>().having((f) => f.kind, 'kind', ExitKind.usage)),
      );
    });
  });

  test('Globs', () {
    expect(Globs.compile('*.log').hasMatch('app.log'), isTrue);
    expect(Globs.compile('*.log').hasMatch('app.log.gz'), isFalse);
    expect(Globs.compile('a?c').hasMatch('abc'), isTrue);
    expect(Globs.compile('a.c').hasMatch('abc'), isFalse);
  });
}
