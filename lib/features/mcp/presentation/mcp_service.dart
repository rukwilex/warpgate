import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/mcp/data/mcp_server.dart';
import 'package:warpgate_core/features/mcp/data/mcp_toolbox.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

export 'package:warpgate_core/features/mcp/data/mcp_toolbox.dart' show McpActivity;

@immutable
class McpServerState {
  const new({this.running = false, this.port, this.error, this.token});

  final bool running;
  final int? port;
  final String? error;
  final String? token;

  String endpoint(int fallbackPort) =>
      'http://127.0.0.1:${port ?? fallbackPort}/mcp';
}

final mcpServerProvider = NotifierProvider<McpController, McpServerState>(
  McpController.new,
);

final mcpActivityProvider = NotifierProvider<McpActivityLog, List<McpActivity>>(
  McpActivityLog.new,
);

class McpActivityLog extends Notifier<List<McpActivity>> {
  static const collection = 'mcp_activity';
  static const keep = 500;

  @override
  List<McpActivity> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final docs = await ref
        .read(documentStoreProvider)
        .all(collection, newestFirst: true, limit: keep);
    state = [for (final json in docs) McpActivity.fromJson(json)];
  }

  Future<void> add(McpActivity entry) async {
    state = [entry, ...state.take(keep - 1)];
    final store = ref.read(documentStoreProvider);
    await store.put(collection, entry.id, entry.toJson(), at: entry.at);
    await store.trim(collection, keep);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(documentStoreProvider).clear(collection);
  }
}

class McpController extends Notifier<McpServerState> {
  McpHttpServer? _server;
  String? _token;

  @override
  McpServerState build() {
    ref.onDispose(() => unawaited(_server?.stop()));
    ref.listen(settingsProvider.select((s) => (s.mcpEnabled, s.mcpPort)), (
      previous,
      next,
    ) {
      unawaited(_apply(enabled: next.$1, port: next.$2));
    });
    final settings = ref.read(settingsProvider);
    if (settings.mcpEnabled) {
      unawaited(
        Future.microtask(() => _apply(enabled: true, port: settings.mcpPort)),
      );
    }
    unawaited(_loadToken());
    return const McpServerState();
  }

  Future<String> _loadToken() async {
    final secrets = ref.read(secretStoreProvider);
    var token = await secrets.read(SecretKeys.mcpToken);
    if (token == null) {
      token = _newToken();
      await secrets.write(SecretKeys.mcpToken, token);
    }
    _token = token;
    state = McpServerState(
      running: state.running,
      port: state.port,
      error: state.error,
      token: token,
    );
    return token;
  }

  static String _newToken() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<void> regenerateToken() async {
    final token = _newToken();
    await ref.read(secretStoreProvider).write(SecretKeys.mcpToken, token);
    _token = token;
    state = McpServerState(
      running: state.running,
      port: state.port,
      error: state.error,
      token: token,
    );
  }

  Future<void> _apply({required bool enabled, required int port}) async {
    await _server?.stop();
    _server = null;
    if (!enabled) {
      state = McpServerState(token: _token);
      return;
    }
    final token = _token ?? await _loadToken();
    final tools = McpToolbox(AppMcpEnvironment(ref));
    final server = McpHttpServer(
      port: port,
      token: () => _token ?? token,
      dispatcher: McpDispatcher(
        tools: () => McpTools.all,
        handle: tools.call,
        instructions:
            "Warpgate is the user's SSH and SFTP workbench. Hosts have per-host permissions. "
            "Use run_command for non-interactive work; it never touches the user's terminal.",
      ),
    );
    try {
      await server.start();
      _server = server;
      state = McpServerState(
        running: true,
        port: server.boundPort,
        token: token,
      );
    } on Object catch (error) {
      state = McpServerState(
        error: 'Port $port is not available: $error',
        token: token,
      );
    }
  }
}

class AppMcpEnvironment implements McpEnvironment {
  new(this._ref);

  final Ref _ref;

  @override
  HostsCatalog get catalog =>
      _ref.read(hostsProvider).value ?? const HostsCatalog();

  @override
  Future<void> get ready => _ref.read(hostsProvider.future);

  @override
  AppSettings get settings => _ref.read(settingsProvider);

  @override
  ConnectionPool get pool => _ref.read(connectionPoolProvider);

  @override
  EndpointResolver get endpoints => _ref.read(endpointResolverProvider);

  @override
  InteractionBroker get broker => _ref.read(interactionBrokerProvider);

  @override
  McpWorkbench get workbench => AppWorkbenchBridge(_ref);

  @override
  McpTransfers get transfers => _AppTransfers(_ref);

  @override
  Future<void> log(McpActivity entry) =>
      _ref.read(mcpActivityProvider.notifier).add(entry);
}

class AppWorkbenchBridge implements McpWorkbench {
  new(this._ref);

  final Ref _ref;

  @override
  List<JsonMap> workspaces() {
    final bench = _ref.read(workbenchProvider);
    return [
      for (final workspace in bench.workspaces)
        {
          'id': workspace.id,
          'name': workspace.name,
          'active': workspace.id == bench.activeWorkspace?.id,
          'tabs': workspace.tabs.length,
        },
    ];
  }

  @override
  List<JsonMap> sessions() {
    final sessions = _ref.read(terminalSessionsProvider);
    final hosts = _ref.read(hostsProvider).value;
    return [
      for (final location in _ref.read(workbenchProvider).allPanes)
        if (location.pane.content case SshTerminalContent(:final hostId))
          {
            'session_id': location.pane.id,
            'host_id': hostId,
            'host_label': hosts?.host(hostId)?.label,
            'workspace_id': location.workspace.id,
            'workspace': location.workspace.name,
            'status':
                sessions[location.pane.id]?.status.value.state.name ?? 'idle',
            'opened_by': location.pane.origin == PaneOrigin.claudeCode
                ? 'claude_code'
                : 'user',
          },
    ];
  }

  @override
  Future<String> openSession(String hostId, {String? workspaceId}) async {
    final paneId = _ref
        .read(workbenchProvider.notifier)
        .openPane(
          SshTerminalContent(hostId: hostId),
          origin: PaneOrigin.claudeCode,
          workspaceId: workspaceId,
        );
    final location = _ref.read(workbenchProvider).locate(paneId)!;
    _ref.read(terminalSessionsProvider).obtain(location.pane);
    return paneId;
  }

  @override
  Future<void> closeSession(String id) async =>
      _ref.read(workbenchProvider.notifier).closePane(id);

  @override
  String? hostOfSession(String id) =>
      _ref.read(workbenchProvider).locate(id)?.pane.content.hostId;

  @override
  String? titleOfSession(String id) =>
      _ref.read(workbenchProvider).locate(id)?.tab.title;

  @override
  Future<String?> readSession(String id, int lines) async =>
      _ref.read(terminalSessionsProvider)[id]?.tail(lines);

  @override
  Future<bool> sendToSession(String id, String text) async {
    final session = _ref.read(terminalSessionsProvider)[id];
    if (session == null) return false;
    session.send(text);
    return true;
  }

  @override
  bool sessionIsLive(String id) =>
      _ref.read(workbenchProvider).locate(id) != null;
}

class _AppTransfers implements McpTransfers {
  new(this._ref);

  final Ref _ref;

  @override
  List<TransferJob> get jobs => _ref.read(transferQueueProvider);

  @override
  TransferJob? byId(String id) =>
      _ref.read(transferQueueProvider.notifier).byId(id);

  @override
  void cancel(String id) => _ref.read(transferQueueProvider.notifier).cancel(id);

  @override
  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    required bool isDirectory,
  }) => _ref
      .read(transferQueueProvider.notifier)
      .enqueue(
        source: source,
        target: target,
        name: name,
        isDirectory: isDirectory,
        origin: 'claude_code',
      );
}
