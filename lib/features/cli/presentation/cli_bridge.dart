import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/snippets/presentation/snippets_controller.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/transfers/presentation/transfer_queue.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/diagnostics/app_log.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';
import 'package:warpgate_core/features/workspace/domain/layout.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';
import 'package:warpgate_core/ipc/ipc.dart';
import 'package:window_manager/window_manager.dart';

final appPathsProvider = Provider<AppPaths?>((ref) => null);

final cliBridgeProvider = Provider<CliBridge?>((ref) {
  final paths = ref.watch(appPathsProvider);
  if (paths == null) return null;
  final bridge = CliBridge(ref, paths);
  ref.onDispose(() => unawaited(bridge.stop()));
  unawaited(bridge.start());
  return bridge;
});

class CliBridge {
  new(this._ref, this._paths);

  final Ref _ref;
  final AppPaths _paths;
  IpcServer? _server;
  Timer? _watcher;
  int? _version;
  WarpgateRuntime? _runtime;

  Future<void> start() async {
    _watcher = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_watch()),
    );
    final server = IpcServer(_paths, handle);
    try {
      await server.start();
      _server = server;
    } on Object catch (error) {
      debugPrint('Could not start the command line connection: $error');
    }
  }

  Future<void> stop() async {
    _watcher?.cancel();
    await _server?.stop();
  }

  Future<void> _watch() async {
    final version = await _ref.read(documentStoreProvider).dataVersion();
    final previous = _version;
    _version = version;
    if (previous != null && previous != version) await reloadAll();
  }

  Future<void> reloadAll() async {
    final store = _ref.read(documentStoreProvider);
    await _ref.read(hostsProvider.notifier).reload();
    await _ref.read(keysProvider.notifier).reload();
    await _ref.read(snippetsProvider.notifier).reload();
    final fresh = await SettingsController.load(store);
    if (jsonEncode(fresh.toJson()) !=
        jsonEncode(_ref.read(settingsProvider).toJson())) {
      await _ref.read(settingsProvider.notifier).reload();
    }
    await _ref.read(transferQueueProvider.notifier).reload();
  }

  WarpgateRuntime get _core => _runtime ??= WarpgateRuntime(
    store: _ref.read(documentStoreProvider),
    secrets: _ref.read(secretStoreProvider),
    broker: _ref.read(interactionBrokerProvider),
  );

  Future<JsonMap> handle(String method, JsonMap params) async {
    switch (method) {
      case 'ping':
        return {'pid': PlatformInfo.isDesktop, 'locked': _locked};
      case 'link.statuses':
        return {
          for (final MapEntry(:key, :value)
              in _ref.read(connectionPoolProvider).statuses.entries)
            key: value.state.name,
        };
    }
    if (_locked) {
      throw const ActionFailure(
        'Warpgate is locked',
        hint: 'Unlock it in the app, then try again',
      );
    }
    switch (method) {
      case 'diagnostics.snapshot':
        final report = _ref.read(appHealthProvider).snapshot();
        if (params['log'] == true) {
          report['log_recent'] = [for (final entry in AppLog.instance.recent) entry.toJson()];
        }
        return report;
      case 'diagnostics.free':
        final trim = await _ref.read(appHealthProvider).freeMemory();
        return trim.toJson();
    }
    final secrets = _ref.read(secretStoreProvider);
    switch (method) {
      case 'secret.read':
        return {'value': await secrets.read(params['key']! as String)};
      case 'secret.write':
        await secrets.write(
          params['key']! as String,
          params['value']! as String,
        );
        return const {};
      case 'secret.delete':
        await secrets.delete(params['key']! as String);
        return const {};
      case 'approve':
        final approved = await _ref
            .read(interactionBrokerProvider)
            .ask(
              ApprovalRequest(
                source: params['source']! as String,
                action: params['action']! as String,
                target: params['target']! as String,
                detail: params['detail']! as String,
              ),
            );
        return {'approved': approved};
      case 'action':
        return await _action(
          params['name']! as String,
          ((params['args'] as Map?) ?? const {}).cast<String, Object?>(),
        );
    }
    throw ActionFailure('Unknown request "$method"');
  }

  bool get _locked => _ref.read(appLockProvider);

  WorkbenchController get _bench => _ref.read(workbenchProvider.notifier);

  CommandRegistry get _commands => _ref.read(commandRegistryProvider);

  Future<void> _front() async {
    if (!PlatformInfo.isDesktop) return;
    try {
      await windowManager.show().timeout(const Duration(seconds: 2));
      await windowManager.focus().timeout(const Duration(seconds: 2));
    } on Object catch (error) {
      debugPrint('Could not bring the window to the front: $error');
    }
  }

  static const JsonMap _done = {'done': true, 'session_id': null};

  String _session(String reference) {
    final panes = [
      for (final location in _ref.read(workbenchProvider).allPanes)
        location.pane.id,
    ];
    final matches = panes
        .where((id) => id == reference || id.startsWith(reference))
        .toList();
    if (matches.length == 1) return matches.single;
    throw ActionFailure(
      matches.isEmpty
          ? 'No session "$reference"'
          : '"$reference" matches several sessions',
      kind: ExitKind.notFound,
      hint: 'Run warpgate sessions list to see them',
    );
  }

  Future<JsonMap> _runCore(String name, JsonMap args) async {
    final handler = ActionHandlers.all[name];
    if (handler == null) throw ActionFailure('The app cannot run $name');
    await _core.loadCatalog();
    final result = await handler(ActionCall(_core, args));
    if (ActionRegistry.byName[name]?.permission != ActionPermission.read) {
      await reloadAll();
    }
    return result;
  }

  Future<JsonMap> _runPalette(String name, JsonMap args) async {
    final action = ActionRegistry.byName[name]!;
    final entry =
        action.palette.firstWhereOrNull(
          (item) =>
              item.args.isNotEmpty &&
              item.args.entries.every(
                (pair) => '${args[pair.key]}' == pair.value,
              ),
        ) ??
        action.palette.firstWhereOrNull((item) => item.args.isEmpty);
    if (entry == null) {
      throw ActionFailure(
        'warpgate ${action.cli} needs more detail',
        kind: ExitKind.usage,
      );
    }
    await _front();
    _commands.run(entry.id);
    return _done;
  }

  Future<JsonMap> _action(String name, JsonMap args) async {
    switch (name) {
      case 'open':
        return await _open(args);
      case 'sessions.list':
        return _sessionsList();
      case 'sessions.open':
        final reference = args['host'] as String?;
        if (reference == null) return await _runPalette(name, args);
        return await _open(args, origin: args['_origin'] as String?);
      case 'sessions.close':
        final id = _session(args['session']! as String);
        _bench.closePane(id);
        return {'done': true, 'session_id': id};
      case 'sessions.focus':
        final reference = args['session'] as String?;
        if (reference == null) return await _runPalette(name, args);
        final id = _session(reference);
        _commands.go(Routes.workbench);
        _bench.reveal(id);
        await _front();
        return {'done': true, 'session_id': id};
      case 'sessions.send':
        final id = _session(args['session']! as String);
        _sendTo(id, args['text']! as String);
        return {'done': true, 'session_id': id};
      case 'sessions.read':
        final id = _session(args['session']! as String);
        final session = _ref.read(terminalSessionsProvider)[id];
        if (session == null) {
          throw ActionFailure('Session "$id" is not running', kind: ExitKind.notFound);
        }
        return {
          'session_id': id,
          'text': session.tail(int.tryParse('${args['lines']}') ?? 100),
        };
      case 'broadcast.send':
        final text = ((args['text'] as List?) ?? const <Object?>[]).join(' ');
        for (final reference
            in ((args['sessions'] as List?) ?? const <Object?>[])
                .cast<String>()) {
          _sendTo(_session(reference), text);
        }
        return _done;
      case 'workspaces.list':
        return {'workspaces': AppWorkbenchBridge(_ref).workspaces()};
      case 'workspaces.open':
        _bench.switchWorkspace(_workspace(args['workspace']! as String));
        _commands.go(Routes.workbench);
        await _front();
        return _done;
      case 'workspaces.save':
      case 'layouts.save':
        final saveName = args['name'] as String?;
        if (saveName == null) return await _runPalette(name, args);
        await _bench.saveActiveTabAs(saveName);
        return _done;
      case 'workspaces.rm':
        _bench.deleteWorkspace(_workspace(args['workspace']! as String));
        return _done;
      case 'workspaces.new':
        final newName = args['name'] as String?;
        if (newName == null) return await _runPalette(name, args);
        _bench.createWorkspace(newName);
        return _done;
      case 'workspaces.rename':
        final rename = args['name'] as String?;
        if (rename == null) return await _runPalette(name, args);
        final active = _ref.read(workbenchProvider).activeWorkspace;
        if (active != null) _bench.renameWorkspace(active.id, rename);
        return _done;
      case 'layouts.apply':
        return await _layout(args);
      case 'groups.open':
        final reference = args['group'] as String?;
        if (reference == null) return await _runPalette(name, args);
        final catalog = await _ref.read(hostsProvider.future);
        final group = HostTargets.group(catalog, reference);
        _commands.openHostsInGrid([
          for (final host in catalog.inGroup(group.id)) host.id,
        ], title: group.name);
        await _front();
        return _done;
      case 'forward.list':
        return await _forwardList(args);
      case 'forward.start':
      case 'forward.stop':
        return await _forwardSwitch(name, args['id']! as String);
      case 'transfers.pause':
      case 'transfers.cancel':
      case 'transfers.resume':
        return await _transfer(name, args['id']! as String);
      case 'transfers.retry':
        return await _retry(args['id']! as String);
      case 'transfers.clear':
        final queue = _ref.read(transferQueueProvider.notifier);
        final before = _ref.read(transferQueueProvider).length;
        queue.clearFinished();
        return {'cleared': before - _ref.read(transferQueueProvider).length};
      case 'files.cp':
        return await _queueCopy(args);
      case 'mcp.token.rotate':
        await _ref.read(mcpServerProvider.notifier).regenerateToken();
        return {'rotated': true};
    }
    final action = ActionRegistry.byName[name];
    if (action == null) throw ActionFailure('Unknown action "$name"');
    if (action.palette.isNotEmpty && action.mode == ActionMode.app) {
      return await _runPalette(name, args);
    }
    return await _runCore(name, args);
  }

  void _sendTo(String id, String text) {
    final session = _ref.read(terminalSessionsProvider)[id];
    if (session == null) {
      throw ActionFailure('Session "$id" is not running', kind: ExitKind.notFound);
    }
    session.send(text.replaceAll(r'\r', '\r').replaceAll(r'\n', '\n'));
  }

  String _workspace(String reference) {
    final found = _ref
        .read(workbenchProvider)
        .workspaces
        .firstWhereOrNull(
          (item) => item.id == reference || item.name == reference,
        );
    if (found != null) return found.id;
    throw ActionFailure(
      'No workspace called "$reference"',
      kind: ExitKind.notFound,
      hint: 'Run warpgate workspaces list to see them',
    );
  }

  JsonMap _sessionsList() {
    final bridge = AppWorkbenchBridge(_ref);
    final terminals = _ref.read(terminalSessionsProvider);
    return {
      'sessions': [
        ...bridge.sessions(),
        for (final location in _ref.read(workbenchProvider).allPanes)
          if (location.pane.content is LocalTerminalContent)
            {
              'session_id': location.pane.id,
              'host_id': null,
              'host_label': 'This device',
              'workspace_id': location.workspace.id,
              'workspace': location.workspace.name,
              'status':
                  terminals[location.pane.id]?.status.value.state.name ?? 'idle',
              'opened_by': 'user',
            },
      ],
    };
  }

  Future<JsonMap> _open(JsonMap args, {String? origin}) async {
    final reference = args['host'] as String?;
    final workspaceRef = args['workspace'] as String?;
    final workspaceId = workspaceRef == null ? null : _workspace(workspaceRef);
    final placement = switch (args['split']) {
      'right' => PanePlacement.splitRight,
      'down' => PanePlacement.splitDown,
      _ => PanePlacement.newTab,
    };
    _commands.go(Routes.workbench);
    await _front();
    if (args['local'] == true) {
      final id = _bench.openPane(
        const LocalTerminalContent(),
        placement: placement,
        workspaceId: workspaceId,
      );
      return {'done': true, 'session_id': id};
    }
    if (reference == null) {
      if (args['files'] == true) return await _runPalette('open', args);
      return _done;
    }
    final catalog = await _ref.read(hostsProvider.future);
    final host = HostTargets.find(catalog, reference);
    if (host == null) {
      throw ActionFailure(
        'No saved host called "$reference"',
        kind: ExitKind.notFound,
        hint: 'The app opens saved hosts. Add it with warpgate hosts add',
      );
    }
    final content = args['files'] == true
        ? SftpContent(
            left: SftpSide(
              hostId: host.id,
              path: _ref.read(settingsProvider).defaultRemotePath,
            ),
          )
        : SshTerminalContent(hostId: host.id);
    final id = _bench.openPane(
      content,
      placement: placement,
      workspaceId: workspaceId,
      origin: origin == 'claude_code' ? PaneOrigin.claudeCode : PaneOrigin.user,
    );
    final location = _ref.read(workbenchProvider).locate(id);
    if (location != null) {
      _ref.read(terminalSessionsProvider).obtain(location.pane);
    }
    return {'done': true, 'session_id': id};
  }

  Future<JsonMap> _layout(JsonMap args) async {
    final name = args['layout'] as String?;
    if (name == null) return await _runPalette('layouts.apply', args);
    final preset = LayoutPresetKind.values.firstWhereOrNull(
      (item) => item.name == name,
    );
    if (preset != null) {
      _bench.applyPreset(preset);
      return _done;
    }
    final saved = await _bench.savedLayouts();
    final layout = saved.firstWhereOrNull(
      (item) => item.name == name || item.id == name,
    );
    if (layout == null) {
      throw ActionFailure(
        'No layout called "$name"',
        kind: ExitKind.notFound,
        hint: 'Run warpgate layouts list to see them',
      );
    }
    _commands.go(Routes.workbench);
    _bench.openSavedLayout(layout);
    await _front();
    return _done;
  }

  Future<JsonMap> _forwardList(JsonMap args) async {
    final catalog = await _ref.read(hostsProvider.future);
    final reference = args['host'] as String?;
    final hosts = reference == null
        ? catalog.hosts
        : [HostTargets.resolve(catalog, reference)];
    final active = {
      for (final item in _ref.read(portForwarderProvider).forwards)
        item.spec.id: item.state.name,
    };
    return {
      'forwards': [
        for (final host in hosts)
          for (final spec in host.forwards)
            Json.forward(host, spec, state: active[spec.id]),
      ],
    };
  }

  Future<JsonMap> _forwardSwitch(String name, String id) async {
    final catalog = await _ref.read(hostsProvider.future);
    for (final host in catalog.hosts) {
      final spec = host.forwards.firstWhereOrNull((item) => item.id == id);
      if (spec == null) continue;
      final forwarder = _ref.read(portForwarderProvider);
      if (name == 'forward.stop') {
        await forwarder.stop(host.id, id);
        return _done;
      }
      await forwarder.start(host.id, spec);
      final state = forwarder.forwards.firstWhereOrNull(
        (item) => item.spec.id == id,
      );
      if (state?.state == ForwardState.failed) {
        throw ActionFailure(
          'Could not start the forward: ${state?.error}',
          kind: ExitKind.connection,
        );
      }
      return _done;
    }
    throw ActionFailure('No forward "$id"', kind: ExitKind.notFound);
  }

  TransferJob _job(String reference) {
    final matches = _ref
        .read(transferQueueProvider)
        .where((job) => job.id == reference || job.id.startsWith(reference))
        .toList();
    if (matches.length == 1) return matches.single;
    throw ActionFailure(
      matches.isEmpty
          ? 'No transfer "$reference"'
          : '"$reference" matches several transfers',
      kind: ExitKind.notFound,
    );
  }

  JsonMap _transferResult(List<TransferJob> jobs) => {
    'transfers': [for (final job in jobs) _transferJson(job)],
    'failed': 0,
  };

  JsonMap _transferJson(TransferJob job) => Json.transfer(_core, job);

  Future<JsonMap> _transfer(String name, String reference) async {
    final job = _job(reference);
    final queue = _ref.read(transferQueueProvider.notifier);
    switch (name) {
      case 'transfers.pause':
        queue.pause(job.id);
      case 'transfers.cancel':
        queue.cancel(job.id);
      case 'transfers.resume':
        queue.resume(job.id);
        await _core.loadCatalog();
        return _transferResult([queue.byId(job.id)!]);
    }
    return {'id': job.id};
  }

  Future<JsonMap> _retry(String reference) async {
    final queue = _ref.read(transferQueueProvider.notifier);
    await _core.loadCatalog();
    if (reference == 'failed') {
      final failed = _ref
          .read(transferQueueProvider)
          .where((job) => job.status == TransferStatus.failed)
          .toList();
      queue.retryFailed();
      return _transferResult([for (final job in failed) queue.byId(job.id)!]);
    }
    final job = _job(reference);
    queue.retry(job.id);
    return _transferResult([queue.byId(job.id)!]);
  }

  Future<JsonMap> _queueCopy(JsonMap args) async {
    final catalog = await _ref.read(hostsProvider.future);
    await _core.loadCatalog();
    final resolver = _ref.read(endpointResolverProvider);
    final queue = _ref.read(transferQueueProvider.notifier);
    final target = PathRef.parse(args['target']! as String);
    String? hostIdOf(PathRef ref) =>
        ref.host == null ? null : HostTargets.resolve(catalog, ref.host!).id;
    final targetHost = hostIdOf(target);
    final targetEndpoint = await resolver.resolve(targetHost);
    final root = await targetEndpoint.resolve(target.path);
    final isFolder =
        (await targetEndpoint.stat(root))?.isDirectory == true ||
        target.path.endsWith('/');
    final ids = <String>[];
    for (final text in (args['sources']! as List).cast<String>()) {
      final ref = PathRef.parse(text);
      final hostId = hostIdOf(ref);
      final endpoint = await resolver.resolve(hostId);
      final path = await endpoint.resolve(ref.path);
      final entry = await endpoint.stat(path);
      if (entry == null) {
        throw ActionFailure('$text does not exist', kind: ExitKind.notFound);
      }
      final name = endpoint.paths.basename(path);
      ids.add(
        queue.enqueue(
          source: TransferRef(hostId: hostId, path: path),
          target: TransferRef(
            hostId: targetHost,
            path: isFolder ? targetEndpoint.paths.join(root, name) : root,
          ),
          name: name,
          isDirectory: entry.isDirectory,
          origin: 'cli',
          move: args['move'] == true,
          mode: args['direct'] == true ? TransferMode.direct : TransferMode.stream,
        ),
      );
    }
    return _transferResult([for (final id in ids) queue.byId(id)!]);
  }
}
