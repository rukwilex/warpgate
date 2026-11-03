import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/mcp/data/mcp_protocol.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

@immutable
class McpActivity {
  const new({
    required this.id,
    required this.at,
    required this.tool,
    required this.arguments,
    required this.summary,
    required this.ok,
  });

  factory fromJson(JsonMap json) => McpActivity(
    id: json['id']! as String,
    at: DateTime.parse(json['at']! as String),
    tool: json['tool']! as String,
    arguments: json['arguments']! as String,
    summary: json['summary']! as String,
    ok: json['ok']! as bool,
  );

  final String id;
  final DateTime at;
  final String tool;
  final String arguments;
  final String summary;
  final bool ok;

  JsonMap toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'tool': tool,
    'arguments': arguments,
    'summary': summary,
    'ok': ok,
  };
}

abstract interface class McpEnvironment {
  HostsCatalog get catalog;

  Future<void> get ready;

  AppSettings get settings;

  ConnectionPool get pool;

  EndpointResolver get endpoints;

  InteractionBroker get broker;

  McpWorkbench get workbench;

  McpTransfers get transfers;

  Future<void> log(McpActivity entry);
}

abstract interface class McpWorkbench {
  List<JsonMap> workspaces();

  List<JsonMap> sessions();

  Future<String> openSession(String hostId, {String? workspaceId});

  Future<void> closeSession(String id);

  String? hostOfSession(String id);

  String? titleOfSession(String id);

  Future<String?> readSession(String id, int lines);

  Future<bool> sendToSession(String id, String text);

  bool sessionIsLive(String id);
}

abstract interface class McpTransfers {
  List<TransferJob> get jobs;

  TransferJob? byId(String id);

  void cancel(String id);

  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    required bool isDirectory,
  });
}

class McpToolbox {
  new(this._env);

  final McpEnvironment _env;

  static const int maxReadBytes = 1024 * 1024;

  HostsCatalog get _catalog => _env.catalog;

  Future<JsonMap> call(String name, JsonMap args) async {
    final spec = McpTools.all.firstWhere((tool) => tool.name == name);
    final started = DateTime.now();
    await _env.ready;
    try {
      final result = await _route(spec, args);
      await _log(name, args, _summarize(result), ok: true, at: started);
      return toolResult(result);
    } on ToolFailure catch (failure) {
      await _log(name, args, failure.message, ok: false, at: started);
      rethrow;
    } on Object catch (error) {
      final message = error is FileOperationException
          ? error.message
          : error.toString();
      await _log(name, args, message, ok: false, at: started);
      throw ToolFailure(message);
    }
  }

  Future<void> _log(
    String tool,
    JsonMap args,
    String summary, {
    required bool ok,
    required DateTime at,
  }) {
    final redacted = {
      for (final MapEntry(:key, :value) in args.entries)
        key: key == 'content' && value is String && value.length > 200
            ? '${value.substring(0, 200)}… (${value.length} chars)'
            : value,
    };
    return _env.log(
          McpActivity(
            id: Ids.next(),
            at: at,
            tool: tool,
            arguments: jsonEncode(redacted),
            summary: summary.length > 400
                ? '${summary.substring(0, 400)}…'
                : summary,
            ok: ok,
          ),
        );
  }

  String _summarize(Object? result) => switch (result) {
    final Map<String, Object?> map when map.containsKey('exit_code') =>
      'exit ${map['exit_code']}',
    final Map<String, Object?> map when map.containsKey('transfer_id') =>
      'transfer ${map['transfer_id']}',
    final Map<String, Object?> map when map.containsKey('session_id') =>
      'session ${map['session_id']}',
    final Map<String, Object?> map => '${map.length} fields',
    _ => 'ok',
  };

  Host _host(String id, {required bool mutating}) {
    final host =
        _catalog.host(id) ??
        _catalog.hosts.firstWhereOrNull((host) => host.label == id);
    if (host == null) {
      throw ToolFailure('No host with id "$id". Call list_hosts to see ids');
    }
    switch (host.mcpPermission) {
      case McpPermission.off:
        throw ToolFailure(
          'Claude Code has no access to ${host.label}. The user can allow it in the host settings',
        );
      case McpPermission.readOnly when mutating:
        throw ToolFailure(
          '${host.label} is read only for Claude Code. This action needs full access',
        );
      case McpPermission.readOnly:
      case McpPermission.full:
        return host;
    }
  }

  Future<void> _approve(McpToolSpec spec, String target, String detail) async {
    if (spec.readOnly || !_env.settings.mcpAskBeforeMutating) {
      return;
    }
    final approved = await _env.broker.ask(
          ApprovalRequest(
            source: 'Claude Code',
            action: spec.title,
            target: target,
            detail: detail,
          ),
        );
    if (!approved) throw const ToolFailure('The user declined this action');
  }

  JsonMap _hostJson(Host host) => {
    'id': host.id,
    'label': host.label,
    'address': host.address,
    'port': host.port,
    'username': host.username,
    'group': _catalog.group(host.groupId)?.name,
    'tags': host.tags,
    'permission': host.mcpPermission.name,
    'jump_host_id': host.jumpHostId,
  };

  Future<Object?> _route(McpToolSpec spec, JsonMap args) async {
    switch (spec.name) {
      case 'list_hosts':
        return {
          'hosts': [
            for (final host in _catalog.hosts)
              if (host.mcpPermission != McpPermission.off) _hostJson(host),
          ],
        };
      case 'list_groups':
        return {
          'groups': [
            for (final group in _catalog.groups)
              {
                'id': group.id,
                'name': group.name,
                'host_ids': [
                  for (final host in _catalog.inGroup(group.id))
                    if (host.mcpPermission != McpPermission.off) host.id,
                ],
              },
          ],
        };
      case 'list_workspaces':
        return {'workspaces': _env.workbench.workspaces()};
      case 'list_sessions':
        return {'sessions': _sessions()};
      case 'open_session':
        final host = _host(ToolArgs.string(args, 'host_id'), mutating: true);
        await _approve(spec, host.label, 'Open a terminal on ${host.endpoint}');
        final paneId = await _env.workbench.openSession(
          host.id,
          workspaceId: ToolArgs.optionalString(args, 'workspace_id'),
        );
        return {'session_id': paneId, 'host_id': host.id};
      case 'close_session':
        final id = ToolArgs.string(args, 'session_id');
        if (!_env.workbench.sessionIsLive(id)) {
          throw ToolFailure('No session "$id"');
        }
        final hostId = _env.workbench.hostOfSession(id);
        if (hostId != null) _host(hostId, mutating: true);
        await _approve(
          spec,
          _env.workbench.titleOfSession(id) ?? 'session',
          'Close session $id',
        );
        await _env.workbench.closeSession(id);
        return {'closed': id};
      case 'run_command':
        final command = ToolArgs.string(args, 'command');
        final timeout = Duration(
          milliseconds: ToolArgs.integer(
            args,
            'timeout_ms',
            fallback: 30000,
            min: 1000,
            max: 600000,
          ),
        );
        final hostId =
            ToolArgs.optionalString(args, 'host_id') ??
            _hostOfSession(ToolArgs.optionalString(args, 'session_id'));
        final host = _host(hostId, mutating: true);
        await _approve(spec, host.label, command);
        final result = await _env.pool.exec(
          host.id,
          command,
          timeout: timeout,
        );
        return {
          'host_id': host.id,
          'exit_code': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
          'duration_ms': result.duration.inMilliseconds,
          'timed_out': result.timedOut,
          'error': ?result.error,
        };
      case 'run_on_hosts':
        final command = ToolArgs.string(args, 'command');
        final timeout = Duration(
          milliseconds: ToolArgs.integer(
            args,
            'timeout_ms',
            fallback: 30000,
            min: 1000,
            max: 600000,
          ),
        );
        final groupId = ToolArgs.optionalString(args, 'group_id');
        final ids =
            ToolArgs.stringList(args, 'host_ids') ??
            (groupId == null
                ? null
                : [for (final host in _catalog.inGroup(groupId)) host.id]);
        if (ids == null || ids.isEmpty) {
          throw const ToolFailure('Pass host_ids or group_id');
        }
        final hosts = [for (final id in ids) _host(id, mutating: true)];
        await _approve(
          spec,
          hosts.map((host) => host.label).join(', '),
          command,
        );
        final pool = _env.pool;
        final results = await Future.wait([
          for (final host in hosts)
            pool.exec(host.id, command, timeout: timeout),
        ]);
        return {
          'results': [
            for (final (index, result) in results.indexed)
              {
                'host_id': hosts[index].id,
                'label': hosts[index].label,
                'exit_code': result.exitCode,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'duration_ms': result.duration.inMilliseconds,
                'timed_out': result.timedOut,
                'error': ?result.error,
              },
          ],
        };
      case 'read_terminal':
        final id = ToolArgs.string(args, 'session_id');
        final hostId = _env.workbench.hostOfSession(id);
        if (hostId != null) _host(hostId, mutating: false);
        final text = await _env.workbench.readSession(
          id,
          ToolArgs.integer(args, 'lines', fallback: 100, min: 1, max: 5000),
        );
        if (text == null) throw ToolFailure('No running session "$id"');
        return {'session_id': id, 'text': text};
      case 'send_input':
        final id = ToolArgs.string(args, 'session_id');
        final text = ToolArgs.string(args, 'text');
        if (!_env.workbench.sessionIsLive(id)) {
          throw ToolFailure('No running session "$id"');
        }
        final hostId = _env.workbench.hostOfSession(id);
        final host = hostId == null ? null : _host(hostId, mutating: true);
        await _approve(spec, host?.label ?? 'local terminal', text);
        if (!await _env.workbench.sendToSession(id, text)) {
          throw ToolFailure('No running session "$id"');
        }
        return {'sent': text.length};
      case 'sftp_list':
        final host = _host(ToolArgs.string(args, 'host_id'), mutating: false);
        final endpoint = await _env.endpoints.resolve(host.id);
        final path = await endpoint.resolve(
          ToolArgs.optionalString(args, 'path') ?? '~',
        );
        final entries = await endpoint.list(path);
        return {
          'path': path,
          'entries': [
            for (final entry
                in entries..sort((a, b) => a.name.compareTo(b.name)))
              {
                'name': entry.name,
                'type': entry.isDirectory
                    ? 'directory'
                    : entry.isLink
                    ? 'link'
                    : 'file',
                'size': entry.size,
                'modified': entry.modified?.toIso8601String(),
                'mode': entry.mode == null
                    ? null
                    : (entry.mode! & 0xFFF).toRadixString(8),
              },
          ],
        };
      case 'sftp_read_file':
        final host = _host(ToolArgs.string(args, 'host_id'), mutating: false);
        final endpoint = await _env.endpoints.resolve(host.id);
        final path = await endpoint.resolve(ToolArgs.string(args, 'path'));
        final limit = ToolArgs.integer(
          args,
          'max_bytes',
          fallback: 256 * 1024,
          min: 1,
          max: maxReadBytes,
        );
        final bytes = await endpoint.readAll(path, maxBytes: limit);
        return {
          'path': path,
          'size': bytes.length,
          'content': utf8.decode(bytes, allowMalformed: true),
        };
      case 'sftp_write_file':
        final host = _host(ToolArgs.string(args, 'host_id'), mutating: true);
        final content = args['content'];
        if (content is! String) {
          throw const ToolFailure('"content" must be a string');
        }
        final endpoint = await _env.endpoints.resolve(host.id);
        final path = await endpoint.resolve(ToolArgs.string(args, 'path'));
        await _approve(
          spec,
          host.label,
          'Write ${content.length} characters to $path',
        );
        await endpoint.writeAll(path, Uint8List.fromList(utf8.encode(content)));
        return {'path': path, 'written': content.length};
      case 'sftp_upload':
        final host = _host(ToolArgs.string(args, 'host_id'), mutating: true);
        final local = ToolArgs.string(args, 'local_path');
        final remote = ToolArgs.string(args, 'remote_path');
        await _approve(spec, host.label, 'Upload $local to $remote');
        return {
          'transfer_id': await _enqueue(
            TransferRef(path: local),
            TransferRef(hostId: host.id, path: remote),
          ),
        };
      case 'sftp_download':
        final host = _host(ToolArgs.string(args, 'host_id'), mutating: false);
        final local = ToolArgs.string(args, 'local_path');
        final remote = ToolArgs.string(args, 'remote_path');
        await _approve(
          const McpToolSpec(
            name: 'sftp_download',
            title: 'Download to this device',
            description: '',
            properties: {},
          ),
          host.label,
          'Download $remote to $local',
        );
        return {
          'transfer_id': await _enqueue(
            TransferRef(hostId: host.id, path: remote),
            TransferRef(path: local),
          ),
        };
      case 'transfer_between_hosts':
        final source = _host(
          ToolArgs.string(args, 'source_host_id'),
          mutating: false,
        );
        final target = _host(
          ToolArgs.string(args, 'target_host_id'),
          mutating: true,
        );
        final sourcePath = ToolArgs.string(args, 'source_path');
        final targetPath = ToolArgs.string(args, 'target_path');
        await _approve(
          spec,
          '${source.label} → ${target.label}',
          '$sourcePath → $targetPath',
        );
        return {
          'transfer_id': await _enqueue(
            TransferRef(hostId: source.id, path: sourcePath),
            TransferRef(hostId: target.id, path: targetPath),
          ),
        };
      case 'list_transfers':
        return {
          'transfers': [
            for (final job
                in _env.transfers.jobs.reversed.take(100))
              {
                'id': job.id,
                'name': job.name,
                'status': job.status.name,
                'source': job.source.toJson(),
                'target': job.target.toJson(),
                'total_bytes': job.totalBytes,
                'done_bytes': job.doneBytes,
                'bytes_per_second': job.bytesPerSecond.round(),
                'error': ?job.error,
              },
          ],
        };
      case 'cancel_transfer':
        final id = ToolArgs.string(args, 'transfer_id');
        final job = _env.transfers.byId(id);
        if (job == null) throw ToolFailure('No transfer "$id"');
        await _approve(spec, job.name, 'Cancel transfer ${job.name}');
        _env.transfers.cancel(id);
        return {'cancelled': id};
    }
    throw ToolFailure('Unknown tool ${spec.name}');
  }

  String _hostOfSession(String? sessionId) {
    if (sessionId == null) {
      throw const ToolFailure('Pass session_id or host_id');
    }
    final hostId = _env.workbench.hostOfSession(sessionId);
    if (hostId == null) {
      throw ToolFailure(
        'Session "$sessionId" is not connected to a saved host',
      );
    }
    return hostId;
  }

  List<JsonMap> _sessions() => [
    for (final session in _env.workbench.sessions())
      if (_catalog.host(session['host_id'] as String?)?.mcpPermission !=
          McpPermission.off)
        session,
  ];

  Future<String> _enqueue(TransferRef source, TransferRef target) async {
    final endpoint = await _env.endpoints.resolve(source.hostId);
    final path = await endpoint.resolve(source.path);
    final entry = await endpoint.stat(path);
    if (entry == null) throw ToolFailure('${source.path} does not exist');
    return _env.transfers.enqueue(
      source: TransferRef(hostId: source.hostId, path: path),
      target: target,
      name: endpoint.paths.basename(path),
      isDirectory: entry.isDirectory,
    );
  }
}
