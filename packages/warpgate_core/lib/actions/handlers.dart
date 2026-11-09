import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';
import 'package:warpgate_core/features/security/data/backup_codec.dart';
import 'package:warpgate_core/features/settings/data/settings_store.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';
import 'package:warpgate_core/features/workspace/domain/layout.dart';

class ActionCall {
  new(this.runtime, this.args, {this.confirm});

  final WarpgateRuntime runtime;
  final JsonMap args;
  final Future<bool> Function(String message)? confirm;

  String string(String name) => args[name]! as String;

  String? maybe(String name) => args[name] as String?;

  bool on(String name) => args[name] == true;

  List<String> list(String name) =>
      ((args[name] as List?) ?? const <Object?>[]).cast<String>();
}

typedef ActionHandler = Future<JsonMap> Function(ActionCall call);

abstract final class Json {
  static JsonMap host(Host host, {required Map<String, String> groups, String status = 'idle'}) => {
    'id': host.id,
    'label': host.label,
    'address': host.address,
    'port': host.port,
    'username': host.username,
    'auth': host.auth.name,
    'key_id': host.keyId,
    'group': groups[host.groupId],
    'tags': host.tags,
    'jump_host_id': host.jumpHostId,
    'tmux': host.tmuxPersistence,
    'mcp_permission': host.mcpPermission.name,
    'status': status,
  };

  static JsonMap key(SshKey key) => {
    'id': key.id,
    'name': key.name,
    'algorithm': key.algorithm.name,
    'fingerprint': key.fingerprint,
    'public_key': key.publicKey,
    'created_at': key.createdAt.toIso8601String(),
    'has_passphrase': key.hasPassphrase,
  };

  static JsonMap knownHost(KnownHost host) => {
    'endpoint': host.endpoint,
    'key_type': host.keyType,
    'fingerprint': host.fingerprint,
    'added_at': host.addedAt.toIso8601String(),
  };

  static JsonMap entry(FileEntry entry) => {
    'name': entry.name,
    'path': entry.path,
    'type': entry.isLink
        ? 'link'
        : entry.isDirectory
        ? 'directory'
        : 'file',
    'size': entry.size,
    'modified': entry.modified?.toIso8601String(),
    'mode': entry.mode == null ? null : (entry.mode! & 0xFFF).toRadixString(8),
    'permissions': entry.permissions,
    'owner': entry.owner,
    'group': entry.group,
  };

  static String _ref(WarpgateRuntime runtime, TransferRef ref) {
    if (ref.hostId == null) return ref.path;
    final label = runtime.lookup(ref.hostId!)?.label ?? ref.hostId;
    return '$label:${ref.path}';
  }

  static JsonMap transfer(WarpgateRuntime runtime, TransferJob job) => {
    'id': job.id,
    'name': job.name,
    'status': job.status.name,
    'source': _ref(runtime, job.source),
    'target': _ref(runtime, job.target),
    'total_bytes': job.totalBytes,
    'done_bytes': job.doneBytes,
    'bytes_per_second': job.bytesPerSecond.round(),
    'origin': job.origin,
    'error': job.error,
  };

  static JsonMap snippet(Snippet snippet) => {
    'id': snippet.id,
    'name': snippet.name,
    'body': snippet.body,
    'variables': [for (final item in snippet.variables) item.name],
  };

  static JsonMap forward(Host host, PortForwardSpec spec, {String? state}) => {
    'id': spec.id,
    'host': host.label,
    'kind': spec.kind.name,
    'bind_host': spec.bindHost,
    'bind_port': spec.bindPort,
    'target_host': spec.targetHost,
    'target_port': spec.targetPort,
    'auto_start': spec.autoStart,
    'state': state,
  };
}

abstract final class ForwardSpecs {
  static PortForwardSpec parse(String kind, String spec, {bool autoStart = false}) {
    final parts = spec.split(':');
    Never bad(String shape) => throw ActionFailure(
      'Could not read "$spec". Use $shape',
      kind: ExitKind.usage,
    );
    int port(String value, String shape) {
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 0 || parsed > 65535) bad(shape);
      return parsed;
    }

    switch (kind) {
      case 'dynamic':
        const shape = '[bind:]port';
        if (parts.length > 2) bad(shape);
        return PortForwardSpec(
          id: Ids.short(),
          kind: ForwardKind.dynamic,
          bindHost: parts.length == 2 ? parts[0] : '127.0.0.1',
          bindPort: port(parts.last, shape),
          autoStart: autoStart,
        );
      default:
        const shape = '[bind:]port:host:hostport';
        if (parts.length < 3 || parts.length > 4) bad(shape);
        final bound = parts.length == 4;
        return PortForwardSpec(
          id: Ids.short(),
          kind: kind == 'remote' ? ForwardKind.remote : ForwardKind.local,
          bindHost: bound ? parts[0] : '127.0.0.1',
          bindPort: port(parts[bound ? 1 : 0], shape),
          targetHost: parts[bound ? 2 : 1],
          targetPort: port(parts[bound ? 3 : 2], shape),
          autoStart: autoStart,
        );
    }
  }
}

abstract final class Globs {
  static RegExp compile(String pattern) {
    final buffer = StringBuffer('^');
    for (final char in pattern.split('')) {
      switch (char) {
        case '*':
          buffer.write('.*');
        case '?':
          buffer.write('.');
        default:
          buffer.write(RegExp.escape(char));
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}

abstract final class ActionHandlers {
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
    'keys.list': _keysList,
    'keys.generate': _keysGenerate,
    'keys.import': _keysImport,
    'keys.export-public': _keysPublic,
    'keys.install': _keysInstall,
    'keys.rm': _keysRm,
    'known-hosts.list': _knownList,
    'known-hosts.rm': _knownRm,
    'known-hosts.trust': _knownTrust,
    'files.ls': _ls,
    'files.cat': _cat,
    'files.mv': _mv,
    'files.rm': _rm,
    'files.mkdir': _mkdir,
    'files.chmod': _chmod,
    'files.stat': _stat,
    'files.find': _find,
    'files.du': _du,
    'transfers.list': _transfersList,
    'transfers.pause': _transfersPause,
    'transfers.cancel': _transfersCancel,
    'transfers.clear': _transfersClear,
    'forward.list': _forwardList,
    'forward.add': _forwardAdd,
    'forward.rm': _forwardRm,
    'snippets.list': _snippetsList,
    'snippets.add': _snippetsAdd,
    'snippets.edit': _snippetsEdit,
    'snippets.rm': _snippetsRm,
    'workspaces.list': _workspacesList,
    'layouts.list': _layoutsList,
    'settings.list': _settingsList,
    'settings.get': _settingsGet,
    'settings.set': _settingsSet,
    'settings.reset': _settingsReset,
    'backup.export': _backupExport,
    'backup.import': _backupImport,
    'mcp.status': _mcpStatus,
    'mcp.token.show': _mcpTokenShow,
    'mcp.token.rotate': _mcpTokenRotate,
  };

  static Map<String, String> _groupNames(WarpgateRuntime rt) => {
    for (final group in rt.hosts.catalog.groups) group.id: group.name,
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
    final names = _groupNames(rt);
    return {
      'hosts': [
        for (final host in hosts)
          Json.host(host, groups: names, status: rt.pool.status(host.id).state.name),
      ],
    };
  }

  static Host _saved(ActionCall call, String reference) {
    final host = call.runtime.host(reference);
    if (host.id.startsWith(HostTargets.adHocPrefix)) {
      throw ActionFailure(
        'No saved host called "$reference"',
        kind: ExitKind.notFound,
        hint: 'Run warpgate hosts list to see saved hosts',
      );
    }
    return host;
  }

  static Future<JsonMap> _hostsShow(ActionCall call) async {
    final host = call.runtime.host(call.string('host'));
    return {
      'host': Json.host(host, groups: _groupNames(call.runtime)),
      'forwards': [for (final spec in host.forwards) Json.forward(host, spec)],
    };
  }

  static AuthMethod _auth(String name) => AuthMethod.values.byName(name);

  static Future<SshKey> _findKey(WarpgateRuntime rt, String reference) async {
    final keys = await rt.keys.all();
    final key = keys.firstWhereOrNull(
      (item) => item.id == reference || item.name == reference,
    );
    if (key != null) return key;
    throw ActionFailure(
      'No key called "$reference"',
      kind: ExitKind.notFound,
      hint: 'Run warpgate keys list to see saved keys',
    );
  }

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
    final key = keyRef == null ? null : await _findKey(rt, keyRef);
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
      jumpHostId: jumpRef == null ? null : _saved(call, jumpRef).id,
      tmuxPersistence: call.on('tmux'),
    );
    await rt.hosts.saveHost(host, password: call.maybe('_password'));
    return {'id': host.id, 'label': host.label};
  }

  static Future<JsonMap> _hostsEdit(ActionCall call) async {
    final rt = call.runtime;
    final host = _saved(call, call.string('host'));
    final keyRef = call.maybe('key');
    final key = keyRef == null ? null : await _findKey(rt, keyRef);
    final groupRef = call.maybe('group');
    final jumpRef = call.maybe('jump');
    final port = call.maybe('port');
    final parsedPort = port == null ? null : int.tryParse(port);
    if (port != null && (parsedPort == null || parsedPort < 1 || parsedPort > 65535)) {
      throw ActionFailure('"$port" is not a valid port', kind: ExitKind.usage);
    }
    final auth = call.maybe('auth');
    final mcp = call.maybe('mcp');
    final tags = call.list('tag');
    if (jumpRef != null && jumpRef != 'none') {
      final jump = _saved(call, jumpRef);
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
          : () => jumpRef == 'none' ? null : _saved(call, jumpRef).id,
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
    final host = _saved(call, call.string('host'));
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
    final names = _groupNames(call.runtime);
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
      final host = _saved(call, name);
      await rt.hosts.saveHost(host.copyWith(groupId: () => groupId));
    }
    return {'moved': hosts.length};
  }

  static Future<JsonMap> _keysList(ActionCall call) async {
    final keys = await call.runtime.keys.all();
    keys.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return {'keys': keys.map(Json.key).toList()};
  }

  static Future<JsonMap> _keysGenerate(ActionCall call) async {
    final name = call.string('name');
    final material = await KeyCodec.generate(
      algorithm: KeyAlgorithm.values.byName(call.maybe('type') ?? 'ed25519'),
      comment: name,
      rsaBits: 4096,
    );
    return Json.key(await call.runtime.keys.save(name: name, material: material));
  }

  static Future<JsonMap> _keysImport(ActionCall call) async {
    final path = call.string('file');
    final file = File(path);
    if (!file.existsSync()) {
      throw ActionFailure('$path does not exist', kind: ExitKind.notFound);
    }
    final pem = await file.readAsString();
    final passphrase = call.maybe('_passphrase');
    final KeyMaterial material;
    try {
      material = KeyCodec.parse(pem, passphrase: passphrase);
    } on KeyFormatException catch (error) {
      throw ActionFailure(
        error.toString(),
        hint: KeyCodec.needsPassphrase(pem) ? 'This key needs a passphrase. Use --passphrase-stdin' : null,
      );
    }
    final name = call.maybe('name') ?? p.basenameWithoutExtension(path);
    return Json.key(
      await call.runtime.keys.save(name: name, material: material, passphrase: passphrase),
    );
  }

  static Future<JsonMap> _keysPublic(ActionCall call) async {
    final key = await _findKey(call.runtime, call.string('key'));
    return {'public_key': key.publicKey};
  }

  static Future<JsonMap> _keysInstall(ActionCall call) async {
    final rt = call.runtime;
    final key = await _findKey(rt, call.string('key'));
    final host = rt.host(call.string('host'));
    await rt.pool.client(host.id);
    final result = await rt.pool.exec(host.id, KeyCodec.installCommand(key.publicKey));
    if (!result.succeeded) {
      throw ActionFailure(
        'Could not install the key: ${result.error ?? result.stderr.trim()}',
      );
    }
    return {'key': key.name, 'host': host.label};
  }

  static Future<JsonMap> _keysRm(ActionCall call) async {
    final key = await _findKey(call.runtime, call.string('key'));
    await call.runtime.keys.delete(key.id);
    return {'id': key.id, 'name': key.name};
  }

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
      timeout: const Duration(seconds: 12),
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
      await client.authenticated.timeout(const Duration(seconds: 15));
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

  static Future<(FileEndpoint, String, PathRef)> _endpoint(ActionCall call, String name) async {
    final ref = PathRef.parse(call.string(name));
    return await _open(call.runtime, ref);
  }

  static Future<(FileEndpoint, String, PathRef)> _open(WarpgateRuntime rt, PathRef ref) async {
    final hostId = ref.host == null ? null : rt.host(ref.host!).id;
    final endpoint = await rt.endpoints.resolve(hostId);
    return (endpoint, await endpoint.resolve(ref.path), ref);
  }

  static List<FileEntry> _sorted(List<FileEntry> entries, String sort) {
    final list = [...entries];
    switch (sort) {
      case 'size':
        list.sort((a, b) => b.size.compareTo(a.size));
      case 'time':
        list.sort(
          (a, b) => (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)),
        );
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  static Future<JsonMap> _ls(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    final showAll = call.on('all');
    final sort = call.maybe('sort') ?? 'name';
    final tree = call.on('tree');
    final rows = <JsonMap>[];
    Future<void> walk(String directory, int depth) async {
      final entries = await endpoint.list(directory);
      for (final entry in _sorted(entries, sort)) {
        if (!showAll && entry.isHidden) continue;
        rows.add({
          ...Json.entry(entry),
          if (tree) 'depth': depth,
        });
        if (tree && entry.isDirectory && !entry.isLink) {
          await walk(entry.path, depth + 1);
        }
      }
    }

    final root = await endpoint.stat(path);
    if (root == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    if (root.isDirectory) {
      await walk(path, 0);
    } else {
      rows.add(Json.entry(root));
    }
    return {'path': path, 'entries': rows};
  }

  static Future<JsonMap> _cat(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    final bytes = await endpoint.readAll(path, maxBytes: 64 * 1024 * 1024);
    return {
      'path': path,
      'size': bytes.length,
      'content': utf8.decode(bytes, allowMalformed: true),
    };
  }

  static Future<JsonMap> _mv(ActionCall call) async {
    final source = PathRef.parse(call.string('source'));
    final rawTarget = call.string('target');
    final parsed = PathRef.parse(rawTarget);
    final targetRef = parsed.isRemote ? parsed : PathRef(parsed.path, host: source.host);
    if (source.host != targetRef.host) {
      throw const ActionFailure(
        'mv works within one host',
        kind: ExitKind.usage,
        hint: 'Use warpgate cp --move to move between hosts',
      );
    }
    final (endpoint, from, _) = await _open(call.runtime, source);
    var to = await endpoint.resolve(targetRef.path);
    final existing = await endpoint.stat(to);
    if (existing != null && existing.isDirectory) {
      to = endpoint.paths.join(to, endpoint.paths.basename(from));
    }
    await endpoint.rename(from, to);
    return {'source': from, 'target': to};
  }

  static Future<JsonMap> _rm(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    final entry = await endpoint.stat(path);
    if (entry == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    if (entry.isDirectory) {
      if (!call.on('recursive')) {
        throw ActionFailure(
          '$path is a folder',
          kind: ExitKind.usage,
          hint: 'Add -r to delete it and everything in it',
        );
      }
      await endpoint.deleteDirectory(path);
    } else {
      await endpoint.deleteFile(path);
    }
    return {'path': path};
  }

  static Future<JsonMap> _mkdir(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    if (call.on('parents')) {
      final missing = <String>[];
      var cursor = path;
      while (!await endpoint.exists(cursor)) {
        missing.add(cursor);
        final parent = endpoint.paths.dirname(cursor);
        if (parent == cursor) break;
        cursor = parent;
      }
      for (final folder in missing.reversed) {
        await endpoint.createDirectory(folder);
      }
    } else {
      await endpoint.createDirectory(path);
    }
    return {'path': path};
  }

  static Future<JsonMap> _chmod(ActionCall call) async {
    final raw = call.string('mode');
    final mode = int.tryParse(raw, radix: 8);
    if (mode == null || mode < 0 || mode > 4095) {
      throw ActionFailure('"$raw" is not an octal mode', kind: ExitKind.usage);
    }
    final (endpoint, path, _) = await _endpoint(call, 'path');
    await endpoint.setMode(path, mode);
    return {'path': path, 'mode': raw};
  }

  static Future<JsonMap> _stat(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    final entry = await endpoint.stat(path);
    if (entry == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    return {'entry': Json.entry(entry)};
  }

  static Future<JsonMap> _find(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    final pattern = Globs.compile(call.string('pattern'));
    final limit = int.tryParse(call.maybe('max') ?? '') ?? 1000;
    final matches = <JsonMap>[];
    var truncated = false;
    Future<void> walk(String directory) async {
      for (final entry in await endpoint.list(directory)) {
        if (matches.length >= limit) {
          truncated = true;
          return;
        }
        if (pattern.hasMatch(entry.name)) matches.add(Json.entry(entry));
        if (entry.isDirectory && !entry.isLink) {
          try {
            await walk(entry.path);
          } on FileOperationException {
            continue;
          }
        }
      }
    }

    await walk(path);
    return {'matches': matches, 'truncated': truncated};
  }

  static Future<JsonMap> _du(ActionCall call) async {
    final (endpoint, path, _) = await _endpoint(call, 'path');
    var files = 0;
    Future<int> measure(FileEntry entry) async {
      if (entry.isLink) return 0;
      if (!entry.isDirectory) {
        files += 1;
        return entry.size;
      }
      var sum = 0;
      try {
        for (final child in await endpoint.list(entry.path)) {
          sum += await measure(child);
        }
      } on FileOperationException {
        return sum;
      }
      return sum;
    }

    final root = await endpoint.stat(path);
    if (root == null) {
      throw ActionFailure('${call.string('path')} does not exist', kind: ExitKind.notFound);
    }
    final children = <JsonMap>[];
    var total = 0;
    if (root.isDirectory) {
      for (final child in await endpoint.list(path)) {
        final size = await measure(child);
        total += size;
        children.add({'name': child.name, 'size': size});
      }
      children.sort((a, b) => (b['size']! as int).compareTo(a['size']! as int));
    } else {
      total = root.size;
      files = 1;
    }
    return {'path': path, 'total': total, 'files': files, 'children': children};
  }

  static Future<List<TransferJob>> _jobs(WarpgateRuntime rt) => TransferScheduler.load(rt.store);

  static Future<TransferJob> findJob(WarpgateRuntime rt, String reference) async {
    final jobs = await _jobs(rt);
    final matches = jobs.where((job) => job.id == reference || job.id.startsWith(reference)).toList();
    if (matches.length == 1) return matches.single;
    throw ActionFailure(
      matches.isEmpty ? 'No transfer "$reference"' : '"$reference" matches several transfers',
      kind: ExitKind.notFound,
      hint: 'Run warpgate transfers list to see them',
    );
  }

  static Future<JsonMap> _transfersList(ActionCall call) async {
    final rt = call.runtime;
    final status = call.maybe('status');
    final jobs = await _jobs(rt);
    return {
      'transfers': [
        for (final job in jobs)
          if (status == null || job.status.name == status) Json.transfer(rt, job),
      ],
    };
  }

  static Future<void> _save(WarpgateRuntime rt, TransferJob job) =>
      rt.store.put(TransferScheduler.collection, job.id, job.toJson(), at: job.createdAt);

  static Future<JsonMap> _transfersPause(ActionCall call) async {
    final rt = call.runtime;
    final job = await findJob(rt, call.string('id'));
    if (job.status == TransferStatus.running && job.ownerPid != null) {
      await rt.store.put(TransferScheduler.controlCollection, job.id, {'action': 'pause'});
    } else {
      await _save(rt, job.copyWith(status: TransferStatus.paused));
    }
    return {'id': job.id};
  }

  static Future<JsonMap> _transfersCancel(ActionCall call) async {
    final rt = call.runtime;
    final job = await findJob(rt, call.string('id'));
    if (job.status == TransferStatus.running && job.ownerPid != null) {
      await rt.store.put(TransferScheduler.controlCollection, job.id, {'action': 'cancel'});
    } else {
      await _save(
        rt,
        job.copyWith(status: TransferStatus.canceled, finishedAt: DateTime.now),
      );
    }
    return {'id': job.id};
  }

  static Future<JsonMap> _transfersClear(ActionCall call) async {
    final rt = call.runtime;
    var cleared = 0;
    for (final job in await _jobs(rt)) {
      if (job.status.isFinished) {
        await rt.store.delete(TransferScheduler.collection, job.id);
        cleared += 1;
      }
    }
    return {'cleared': cleared};
  }

  static Future<JsonMap> _forwardList(ActionCall call) async {
    final rt = call.runtime;
    final reference = call.maybe('host');
    final hosts = reference == null ? rt.hosts.catalog.hosts : [_saved(call, reference)];
    final active = {
      for (final forward in rt.forwarder.forwards) forward.spec.id: forward.state.name,
    };
    return {
      'forwards': [
        for (final host in hosts)
          for (final spec in host.forwards)
            Json.forward(host, spec, state: active[spec.id]),
      ],
    };
  }

  static Future<JsonMap> _forwardAdd(ActionCall call) async {
    final host = _saved(call, call.string('host'));
    final chosen = [
      for (final kind in const ['local', 'remote', 'dynamic'])
        if (call.maybe(kind) != null) kind,
    ];
    if (chosen.length != 1) {
      throw const ActionFailure('Pick exactly one of -L, -R or -D', kind: ExitKind.usage);
    }
    final spec = ForwardSpecs.parse(
      chosen.single,
      call.string(chosen.single),
      autoStart: call.on('auto-start'),
    );
    await call.runtime.hosts.saveHost(host.copyWith(forwards: [...host.forwards, spec]));
    return {'id': spec.id, 'host': host.label};
  }

  static Future<JsonMap> _forwardRm(ActionCall call) async {
    final id = call.string('id');
    for (final host in call.runtime.hosts.catalog.hosts) {
      if (host.forwards.any((spec) => spec.id == id)) {
        await call.runtime.hosts.saveHost(
          host.copyWith(forwards: host.forwards.where((spec) => spec.id != id).toList()),
        );
        return {'id': id};
      }
    }
    throw ActionFailure('No forward "$id"', kind: ExitKind.notFound);
  }

  static Future<Snippet> findSnippet(WarpgateRuntime rt, String reference) async {
    final snippets = await rt.snippets.all();
    final found = snippets.firstWhereOrNull((item) => item.id == reference || item.name == reference);
    if (found != null) return found;
    throw ActionFailure(
      'No snippet called "$reference"',
      kind: ExitKind.notFound,
      hint: 'Run warpgate snippets list to see them',
    );
  }

  static Future<JsonMap> _snippetsList(ActionCall call) async => {
    'snippets': (await call.runtime.snippets.all()).map(Json.snippet).toList(),
  };

  static Future<JsonMap> _snippetsAdd(ActionCall call) async {
    final snippet = await call.runtime.snippets.save(
      name: call.string('name'),
      body: call.string('body'),
    );
    return {'id': snippet.id, 'name': snippet.name};
  }

  static Future<JsonMap> _snippetsEdit(ActionCall call) async {
    final rt = call.runtime;
    final current = await findSnippet(rt, call.string('snippet'));
    final saved = await rt.snippets.save(
      id: current.id,
      name: call.maybe('name') ?? current.name,
      body: call.maybe('body') ?? current.body,
    );
    return {'id': saved.id, 'name': saved.name};
  }

  static Future<JsonMap> _snippetsRm(ActionCall call) async {
    final snippet = await findSnippet(call.runtime, call.string('snippet'));
    await call.runtime.snippets.delete(snippet.id);
    return {'id': snippet.id, 'name': snippet.name};
  }

  static Future<JsonMap> _workspacesList(ActionCall call) async {
    final json = await call.runtime.store.get('workbench', 'state');
    final active = json?['activeWorkspaceId'];
    return {
      'workspaces': [
        for (final item in (json?['workspaces'] as List?) ?? const <Object?>[])
          if (item is Map)
            {
              'id': item['id'],
              'name': item['name'],
              'active': item['id'] == active,
              'tabs': (item['tabs'] as List?)?.length ?? 0,
            },
      ],
    };
  }

  static Future<JsonMap> _layoutsList(ActionCall call) async => {
    'layouts': [
      for (final json in await call.runtime.store.all('saved_layouts', newestFirst: true))
        {'id': json['id'], 'name': json['name'], 'saved_at': json['savedAt']},
    ],
    'presets': [for (final preset in LayoutPresetKind.values) preset.name],
  };

  static JsonMap _setting(SettingField field, JsonMap values) {
    final defaults = const AppSettings().toJson();
    return {
      'key': field.key,
      'value': values[field.key],
      'default': defaults[field.key],
      'type': field.type,
      'choices': field.choices,
    };
  }

  static Future<JsonMap> _settingsList(ActionCall call) async {
    final values = (await call.runtime.settings.load()).toJson();
    return {
      'settings': [for (final field in SettingsStore.fields) _setting(field, values)],
    };
  }

  static SettingField _field(String key) {
    try {
      return SettingsStore.field(key);
    } on SettingValueError catch (error) {
      throw ActionFailure(error.message, kind: ExitKind.notFound);
    }
  }

  static Future<JsonMap> _settingsGet(ActionCall call) async {
    final field = _field(call.string('key'));
    return _setting(field, (await call.runtime.settings.load()).toJson());
  }

  static Future<JsonMap> _settingsSet(ActionCall call) async {
    final field = _field(call.string('key'));
    final Object? value;
    try {
      value = SettingsStore.coerce(field.key, call.string('value'));
    } on SettingValueError catch (error) {
      throw ActionFailure(error.message, kind: ExitKind.usage);
    }
    final next = await call.runtime.settings.patch({field.key: value});
    return _setting(field, next.toJson());
  }

  static Future<JsonMap> _settingsReset(ActionCall call) async {
    final key = call.maybe('key');
    final defaults = const AppSettings().toJson();
    if (key != null) {
      _field(key);
      await call.runtime.settings.patch({key: defaults[key]});
      return {'reset': 1};
    }
    final current = (await call.runtime.settings.load()).toJson();
    final keys = SettingsStore.fields.map((field) => field.key).toSet();
    await call.runtime.settings.patch({
      for (final MapEntry(key: name, :value) in defaults.entries)
        name: keys.contains(name) ? value : current[name],
    });
    return {'reset': keys.length};
  }

  static Future<JsonMap> _backupExport(ActionCall call) async {
    final path = call.string('file');
    final withSecrets = call.on('with-secrets');
    final content = await call.runtime.backup.export(
      passphrase: call.string('_passphrase'),
      includeSecrets: withSecrets,
    );
    final file = File(path);
    await file.writeAsString('', flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', path]);
    }
    await file.writeAsString(content, flush: true);
    return {'file': path, 'with_secrets': withSecrets};
  }

  static Future<JsonMap> _backupImport(ActionCall call) async {
    final path = call.string('file');
    final file = File(path);
    if (!file.existsSync()) {
      throw ActionFailure('$path does not exist', kind: ExitKind.notFound);
    }
    final raw = await file.readAsString();
    try {
      final summary = await call.runtime.backup.restore(raw, call.string('_passphrase'));
      return {'hosts': summary.hosts, 'keys': summary.keys, 'snippets': summary.snippets};
    } on BackupException catch (error) {
      throw ActionFailure(error.toString());
    }
  }

  static Future<JsonMap> _mcpStatus(ActionCall call) async {
    final settings = await call.runtime.settings.load();
    return {
      'state': settings.mcpEnabled ? 'on' : 'off',
      'enabled': settings.mcpEnabled,
      'port': settings.mcpPort,
      'allowed': call.runtime.hosts.catalog.hosts
          .where((host) => host.mcpPermission != McpPermission.off)
          .length,
      'tools': McpTools.all.length,
    };
  }

  static String newToken() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<JsonMap> _mcpTokenShow(ActionCall call) async {
    final secrets = call.runtime.secrets;
    var token = await secrets.read(SecretKeys.mcpToken);
    if (token == null) {
      token = newToken();
      await secrets.write(SecretKeys.mcpToken, token);
    }
    return {'token': token};
  }

  static Future<JsonMap> _mcpTokenRotate(ActionCall call) async {
    await call.runtime.secrets.write(SecretKeys.mcpToken, newToken());
    return {'rotated': true};
  }
}
