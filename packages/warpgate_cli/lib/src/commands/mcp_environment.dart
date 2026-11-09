import 'dart:async';
import 'dart:io';

import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/copy.dart';
import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/mcp/data/mcp_protocol.dart';
import 'package:warpgate_core/features/mcp/data/mcp_toolbox.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

class CliMcpEnvironment implements McpEnvironment {
  new(this._context, this._runtime);

  final CliContext _context;
  final WarpgateRuntime _runtime;
  late AppSettings _settings;
  late final _workbench = _IpcWorkbench(_context);
  late final _transfers = _LocalTransfers(_runtime);
  late final InteractionBroker _broker = _approvals();

  Future<void> settle() async => _settings = await _runtime.settings.load();

  InteractionBroker _approvals() {
    final broker = InteractionBroker()..attach();
    broker.requests.listen((request) {
      unawaited(() async {
        if (request is! ApprovalRequest) {
          request.dismiss();
          return;
        }
        final client = await _context.client();
        if (client == null) {
          request.dismiss();
          return;
        }
        try {
          final reply = await client.call('approve', {
            'source': request.source,
            'action': request.action,
            'target': request.target,
            'detail': request.detail,
          });
          request.respond(reply['approved'] == true);
        } on Object {
          request.dismiss();
        }
      }());
    });
    return broker;
  }

  @override
  HostsCatalog get catalog => _runtime.hosts.catalog;

  @override
  Future<void> get ready async {
    await _runtime.loadCatalog();
    await settle();
    await _workbench.refresh();
  }

  @override
  AppSettings get settings => _settings;

  @override
  ConnectionPool get pool => _runtime.pool;

  @override
  EndpointResolver get endpoints => _runtime.endpoints;

  @override
  InteractionBroker get broker => _broker;

  @override
  McpWorkbench get workbench => _workbench;

  @override
  McpTransfers get transfers => _transfers;

  @override
  Future<void> log(McpActivity entry) async {
    await _runtime.store.put(StoreKeys.mcpActivity, entry.id, entry.toJson(), at: entry.at);
    await _runtime.store.trim(StoreKeys.mcpActivity, ActionLimits.mcpActivityKept);
  }
}

class _IpcWorkbench implements McpWorkbench {
  new(this._context);

  final CliContext _context;
  List<JsonMap> _sessions = const [];
  List<JsonMap> _workspaces = const [];

  static const _needsApp = ToolFailure(
    'This needs the Warpgate app, and it is not running. Ask the user to open it',
  );

  Future<JsonMap> _action(String name, JsonMap args) async {
    final client = await _context.client();
    if (client == null) throw _needsApp;
    return await client.call('action', {'name': name, 'args': args});
  }

  Future<void> refresh() async {
    final client = await _context.client();
    if (client == null) {
      final stored = await _context.store.get(StoreKeys.workbench, StoreKeys.workbenchState);
      final active = stored?['activeWorkspaceId'];
      _workspaces = [
        for (final item in (stored?['workspaces'] as List?) ?? const <Object?>[])
          if (item is Map)
            {
              'id': item['id'],
              'name': item['name'],
              'active': item['id'] == active,
              'tabs': (item['tabs'] as List?)?.length ?? 0,
            },
      ];
      _sessions = const [];
      return;
    }
    final sessions = await client.call('action', {'name': 'sessions.list', 'args': const <String, Object?>{}});
    _sessions = ((sessions['sessions'] as List?) ?? const <Object?>[]).cast<JsonMap>();
    final workspaces = await client.call('action', {'name': 'workspaces.list', 'args': const <String, Object?>{}});
    _workspaces = ((workspaces['workspaces'] as List?) ?? const <Object?>[]).cast<JsonMap>();
  }

  JsonMap? _find(String id) {
    for (final session in _sessions) {
      if (session['session_id'] == id) return session;
    }
    return null;
  }

  @override
  List<JsonMap> workspaces() => _workspaces;

  @override
  List<JsonMap> sessions() => _sessions;

  @override
  Future<String> openSession(String hostId, {String? workspaceId}) async {
    final result = await _action('sessions.open', {
      'host': hostId,
      'workspace': ?workspaceId,
      '_origin': ActionOrigins.claudeCode,
    });
    return result['session_id']! as String;
  }

  @override
  Future<void> closeSession(String id) => _action('sessions.close', {'session': id});

  @override
  String? hostOfSession(String id) => _find(id)?['host_id'] as String?;

  @override
  String? titleOfSession(String id) => _find(id)?['host_label'] as String?;

  @override
  Future<String?> readSession(String id, int lines) async {
    final result = await _action('sessions.read', {'session': id, 'lines': '$lines'});
    return result['text'] as String?;
  }

  @override
  Future<bool> sendToSession(String id, String text) async {
    await _action('sessions.send', {'session': id, 'text': text});
    return true;
  }

  @override
  bool sessionIsLive(String id) => _find(id) != null;
}

class _LocalTransfers implements McpTransfers {
  new(WarpgateRuntime runtime) : _queue = CopyCommands.scheduler(runtime);

  final TransferScheduler _queue;

  @override
  List<TransferJob> get jobs => _queue.jobs;

  @override
  TransferJob? byId(String id) => _queue.byId(id);

  @override
  void cancel(String id) => _queue.cancel(id);

  @override
  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    required bool isDirectory,
  }) {
    final id = _queue.enqueue(
      source: source,
      target: target,
      name: name,
      isDirectory: isDirectory,
      origin: ActionOrigins.claudeCode,
      ownerPid: pid,
      start: false,
    );
    unawaited(_queue.run(id, policy: ConflictPolicy.overwrite));
    return id;
  }
}
