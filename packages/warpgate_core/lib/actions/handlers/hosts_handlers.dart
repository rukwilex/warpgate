import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/support/lookups.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

abstract final class HostHandlers {
  static final Map<String, ActionHandler> all = {
    'hosts.list': _hostsList,
    'hosts.show': _hostsShow,
    'hosts.add': _hostsAdd,
    'hosts.edit': _hostsEdit,
    'hosts.rm': _hostsRm,
    'hosts.test': _hostsTest,
    'hosts.import-ssh-config': _hostsImport,
    'hosts.export': _hostsExport,
    'groups.list': _groupsList,
    'groups.add': _groupsAdd,
    'groups.rm': _groupsRm,
    'groups.move': _groupsMove,
  };

  static Future<JsonMap> _hostsList(ActionCall call) async {
    final rt = call.runtime;
    final catalog = rt.hosts.catalog;
    var hosts = catalog.hosts;
    final group = call.maybe('group');
    if (group != null) {
      hosts = catalog.inGroup(HostTargets.group(catalog, group).id);
    }
    final tag = call.maybe('tag');
    if (tag != null) hosts = hosts.where((h) => h.tags.contains(tag)).toList();
    final names = Lookups.groupNames(rt);
    return {
      'hosts': [
        for (final host in hosts)
          Json.host(host, groups: names, status: rt.pool.status(host.id).state.name),
      ],
    };
  }

  static Future<JsonMap> _hostsShow(ActionCall call) async {
    final host = call.runtime.host(call.string('host'));
    return {
      'host': Json.host(host, groups: Lookups.groupNames(call.runtime)),
      'forwards': [for (final spec in host.forwards) Json.forward(host, spec)],
    };
  }

  static AuthMethod _auth(String name) => AuthMethod.values.byName(name);

  static Future<JsonMap> _hostsAdd(ActionCall call) async {
    final rt = call.runtime;
    final label = call.string('label');
    if (rt.hosts.catalog.hosts.any((host) => host.label == label)) {
      throw ActionFailure(
        'A host called "$label" already exists',
        hint: 'Use warpgate hosts edit $label to change it',
      );
    }
    final target = call.string('target');
    final endpoint = HostTargets.parseEndpoint(
      target.contains('@') || target.contains(':') ? target : 'root@$target',
    );
    if (endpoint == null) {
      throw ActionFailure(
        'Could not read "$target". Use user@host[:port]',
        kind: ExitKind.usage,
      );
    }
    final keyRef = call.maybe('key');
    final key = keyRef == null ? null : await Lookups.findKey(rt, keyRef);
    final groupRef = call.maybe('group');
    final jumpRef = call.maybe('jump');
    final host = Host(
      id: Ids.next(),
      label: label,
      address: endpoint.address,
      port: endpoint.port,
      username: endpoint.user,
      auth: key != null ? AuthMethod.key : _auth(call.maybe('auth') ?? 'agent'),
      keyId: key?.id,
      groupId: groupRef == null ? null : HostTargets.group(rt.hosts.catalog, groupRef).id,
      tags: call.list('tag'),
      jumpHostId: jumpRef == null ? null : Lookups.savedHost(call, jumpRef).id,
      tmuxPersistence: call.on('tmux'),
    );
    await rt.hosts.saveHost(host, password: call.maybe('_password'));
    return {'id': host.id, 'label': host.label};
  }

  static Future<JsonMap> _hostsEdit(ActionCall call) async {
    final rt = call.runtime;
    final host = Lookups.savedHost(call, call.string('host'));
    final keyRef = call.maybe('key');
    final key = keyRef == null ? null : await Lookups.findKey(rt, keyRef);
    final groupRef = call.maybe('group');
    final jumpRef = call.maybe('jump');
    final port = call.maybe('port');
    final parsedPort = port == null ? null : int.tryParse(port);
    if (port != null && (parsedPort == null || parsedPort < 1 || parsedPort > ActionLimits.maxPort)) {
      throw ActionFailure('"$port" is not a valid port', kind: ExitKind.usage);
    }
    final auth = call.maybe('auth');
    final mcp = call.maybe('mcp');
    final tags = call.list('tag');
    if (jumpRef != null && jumpRef != 'none') {
      final jump = Lookups.savedHost(call, jumpRef);
      if (HostChain.wouldCycle(host.id, jump.id, rt.hosts.catalog.byId)) {
        throw ActionFailure('${jump.label} already connects through ${host.label}');
      }
    }
    final next = host.copyWith(
      label: call.maybe('label'),
      address: call.maybe('address'),
      port: parsedPort,
      username: call.maybe('user'),
      auth: key != null ? AuthMethod.key : (auth == null ? null : _auth(auth)),
      keyId: key == null ? null : () => key.id,
      groupId: groupRef == null
          ? null
          : () => groupRef == 'none' ? null : HostTargets.group(rt.hosts.catalog, groupRef).id,
      jumpHostId: jumpRef == null
          ? null
          : () => jumpRef == 'none' ? null : Lookups.savedHost(call, jumpRef).id,
      tags: tags.isEmpty ? null : tags,
      mcpPermission: mcp == null ? null : McpPermission.values.byName(mcp),
    );
    await rt.hosts.saveHost(
      next,
      password: call.maybe('_password'),
      clearPassword: call.on('clear-password'),
    );
    return {'id': next.id, 'label': next.label};
  }

  static Future<JsonMap> _hostsRm(ActionCall call) async {
    final host = Lookups.savedHost(call, call.string('host'));
    await call.runtime.hosts.deleteHost(host.id);
    return {'id': host.id, 'label': host.label};
  }

  static Future<JsonMap> _hostsTest(ActionCall call) async {
    final rt = call.runtime;
    final host = rt.host(call.string('host'));
    final watch = Stopwatch()..start();
    final client = await rt.pool.client(host.id);
    return {
      'label': host.label,
      'ok': true,
      'duration_ms': watch.elapsedMilliseconds,
      'server': client.remoteVersion,
    };
  }

  static Future<JsonMap> _hostsImport(ActionCall call) async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final path = call.maybe('file') ?? p.join(home, '.ssh', 'config');
    final file = File(path);
    if (!file.existsSync()) {
      throw ActionFailure('$path does not exist', kind: ExitKind.notFound);
    }
    return {'imported': await call.runtime.hosts.importSshConfig(await file.readAsString())};
  }

  static Future<JsonMap> _hostsExport(ActionCall call) async {
    final catalog = call.runtime.hosts.catalog;
    final names = Lookups.groupNames(call.runtime);
    if (call.maybe('format') == 'json') {
      return {
        'content': const JsonEncoder.withIndent('  ').convert([
          for (final host in catalog.hosts) Json.host(host, groups: names),
        ]),
        'count': catalog.hosts.length,
      };
    }
    final buffer = StringBuffer();
    for (final host in catalog.hosts) {
      buffer
        ..writeln('Host ${host.label}')
        ..writeln('  HostName ${host.address}')
        ..writeln('  User ${host.username}')
        ..writeln('  Port ${host.port}');
      final jump = catalog.host(host.jumpHostId);
      if (jump != null) buffer.writeln('  ProxyJump ${jump.label}');
      buffer.writeln();
    }
    return {'content': buffer.toString().trimRight(), 'count': catalog.hosts.length};
  }

  static Future<JsonMap> _groupsList(ActionCall call) async {
    final catalog = call.runtime.hosts.catalog;
    return {
      'groups': [
        for (final group in catalog.groups)
          {
            'id': group.id,
            'name': group.name,
            'hosts': [for (final host in catalog.inGroup(group.id)) host.label],
          },
      ],
    };
  }

  static Future<JsonMap> _groupsAdd(ActionCall call) async {
    final group = await call.runtime.hosts.addGroup(call.string('name'));
    return {'id': group.id, 'name': group.name};
  }

  static Future<JsonMap> _groupsRm(ActionCall call) async {
    final rt = call.runtime;
    final group = HostTargets.group(rt.hosts.catalog, call.string('group'));
    await rt.hosts.deleteGroup(group.id);
    return {'id': group.id, 'name': group.name};
  }

  static Future<JsonMap> _groupsMove(ActionCall call) async {
    final rt = call.runtime;
    final reference = call.string('group');
    final groupId = reference == 'none'
        ? null
        : HostTargets.group(rt.hosts.catalog, reference).id;
    final hosts = call.list('hosts');
    for (final name in hosts) {
      final host = Lookups.savedHost(call, name);
      await rt.hosts.saveHost(host.copyWith(groupId: () => groupId));
    }
    return {'moved': hosts.length};
  }
}
