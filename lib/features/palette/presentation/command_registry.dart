import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/shortcuts/shortcut_codec.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
import 'package:warpgate/design_system/components/wg_overlays.dart';
import 'package:warpgate/design_system/tokens/wg_metrics.dart';
import 'package:warpgate/features/hosts/presentation/host_picker.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/domain/app_command.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/sftp/application/file_places.dart';
import 'package:warpgate/features/shell/presentation/prompts.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/snippets/presentation/snippet_runner.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/presentation/saved_layouts_dialog.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/features/workspace/domain/layout.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => throw UnimplementedError('routerProvider must be overridden'),
);

abstract final class DefaultShortcuts {
  static SingleActivator _p(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) => ShortcutCodec.primary(key, shift: shift, alt: alt);

  static SingleActivator _plain(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) => ShortcutCodec.plain(key, shift: shift, alt: alt);

  static final Map<String, SingleActivator> map = {
    'palette.open': _p(LogicalKeyboardKey.keyK),
    'palette.switcher': _p(LogicalKeyboardKey.keyP),
    'session.new': _p(LogicalKeyboardKey.keyT),
    'session.local': _p(LogicalKeyboardKey.keyT, shift: true),
    'sftp.new': _p(LogicalKeyboardKey.keyO),
    'sftp.here': _p(LogicalKeyboardKey.keyF, shift: true),
    'pane.splitRight': _p(LogicalKeyboardKey.keyD),
    'pane.splitDown': _p(LogicalKeyboardKey.keyD, shift: true),
    'pane.close': _p(LogicalKeyboardKey.keyW),
    'pane.maximize': _p(LogicalKeyboardKey.enter, shift: true),
    'pane.focusLeft': _plain(LogicalKeyboardKey.arrowLeft, alt: true),
    'pane.focusRight': _plain(LogicalKeyboardKey.arrowRight, alt: true),
    'pane.focusUp': _plain(LogicalKeyboardKey.arrowUp, alt: true),
    'pane.focusDown': _plain(LogicalKeyboardKey.arrowDown, alt: true),
    'pane.growLeft': _plain(
      LogicalKeyboardKey.arrowLeft,
      shift: true,
      alt: true,
    ),
    'pane.growRight': _plain(
      LogicalKeyboardKey.arrowRight,
      shift: true,
      alt: true,
    ),
    'pane.growUp': _plain(LogicalKeyboardKey.arrowUp, shift: true, alt: true),
    'pane.growDown': _plain(
      LogicalKeyboardKey.arrowDown,
      shift: true,
      alt: true,
    ),
    'tab.next': const SingleActivator(LogicalKeyboardKey.tab, control: true),
    'tab.previous': const SingleActivator(
      LogicalKeyboardKey.tab,
      control: true,
      shift: true,
    ),
    'broadcast.toggle': _p(LogicalKeyboardKey.keyB, shift: true),
    'multiExec.open': _p(LogicalKeyboardKey.keyE, shift: true),
    'snippets.run': _p(LogicalKeyboardKey.keyS, shift: true),
    'transfers.open': _p(LogicalKeyboardKey.keyJ, shift: true),
    'sidebar.toggle': _p(LogicalKeyboardKey.keyB),
    'settings.open': _p(LogicalKeyboardKey.comma),
    'layout.save': _p(LogicalKeyboardKey.keyL, shift: true),
    'terminal.zoomIn': _p(LogicalKeyboardKey.equal),
    'terminal.zoomOut': _p(LogicalKeyboardKey.minus),
    'terminal.zoomReset': _p(LogicalKeyboardKey.digit0),
    'app.lock': _p(LogicalKeyboardKey.keyL, alt: true),
    for (var i = 1; i <= 9; i++)
      'workspace.$i': PlatformInfo.isApple
          ? SingleActivator(LogicalKeyboardKey(0x30 + i), meta: true)
          : SingleActivator(LogicalKeyboardKey(0x30 + i), control: true),
  };
}

final shortcutMapProvider = Provider<Map<String, SingleActivator>>((ref) {
  final overrides = ref.watch(
    settingsProvider.select((s) => s.shortcutOverrides),
  );
  return {
    ...DefaultShortcuts.map,
    for (final MapEntry(:key, :value) in overrides.entries)
      key: ?ShortcutCodec.decode(value),
  }..removeWhere((key, _) => overrides[key] == '');
});

class CommandRegistry {
  new(this._ref);

  static final Map<String, PaletteEntry> _paletteEntries = {
    for (final entry in ActionRegistry.paletteEntries) entry.id: entry,
  };

  final Ref _ref;

  BuildContext? get _context => rootNavigatorKey.currentContext;

  WorkbenchController get _bench => _ref.read(workbenchProvider.notifier);

  void _go(String route) {
    _ref.read(routerProvider).go(route);
  }

  void go(String route) => _go(route);

  void run(String id) {
    final command = commands().where((command) => command.id == id).firstOrNull;
    command?.run();
  }

  Future<void> newSession({
    PanePlacement placement = PanePlacement.newTab,
  }) async {
    final context = _context;
    if (context == null) return;
    final host = await showHostPicker(
      context,
      title: placement == PanePlacement.newTab
          ? 'Open a terminal'
          : 'Open beside',
    );
    if (host == null) return;
    _go(Routes.workbench);
    _bench.openPane(SshTerminalContent(hostId: host.id), placement: placement);
  }

  Future<void> newSftp({PanePlacement placement = PanePlacement.newTab}) async {
    final context = _context;
    if (context == null) return;
    final pick = await showEndpointPicker(context, title: 'Browse files on');
    if (pick == null) return;
    final host = pick.host;
    _go(Routes.workbench);
    _bench.openPane(
      SftpContent(
        left: SftpSide(
          hostId: host?.id,
          path: host == null
              ? null
              : _ref.read(settingsProvider).defaultRemotePath,
        ),
      ),
      placement: placement,
    );
  }

  void toggleFiles() {
    final pane = _ref.read(workbenchProvider).focusedPane;
    if (pane == null || pane.content is! TerminalContent) {
      openSftpHere();
      return;
    }
    _bench.updateAttachedFiles(
      pane.id,
      (files) => files.copyWith(open: !files.open),
    );
  }

  HostOpenMode lastOpenMode(String hostId) {
    final saved = _ref.read(settingsProvider).hostOpenModes[hostId];
    return HostOpenMode.values
            .where((mode) => mode.name == saved)
            .firstOrNull ??
        HostOpenMode.terminal;
  }

  void openHost(
    String hostId, {
    HostOpenMode? mode,
    PanePlacement placement = PanePlacement.newTab,
  }) {
    final chosen = mode ?? lastOpenMode(hostId);
    if (mode != null) {
      final modes = _ref.read(settingsProvider).hostOpenModes;
      if (modes[hostId] != mode.name) {
        _ref.read(settingsProvider.notifier).update({
          'hostOpenModes': {...modes, hostId: mode.name},
        });
      }
    }
    _go(Routes.workbench);
    _bench.openPane(switch (chosen) {
      HostOpenMode.terminal => SshTerminalContent(hostId: hostId),
      HostOpenMode.files => SftpContent(
        left: SftpSide(
          hostId: hostId,
          path: _ref.read(settingsProvider).defaultRemotePath,
        ),
      ),
      HostOpenMode.both => SshTerminalContent(
        hostId: hostId,
        files: const AttachedFiles(open: true),
      ),
    }, placement: placement);
  }

  List<WgMenuEntry> openHostEntries(String hostId) {
    final last = lastOpenMode(hostId);
    return [
      for (final mode in HostOpenMode.values)
        WgMenuEntry(
          label: 'Open ${mode.label.toLowerCase()}',
          icon: switch (mode) {
            HostOpenMode.terminal => WgIcons.terminal,
            HostOpenMode.files => WgIcons.folder,
            HostOpenMode.both => WgIcons.filesPanel,
          },
          trailing: mode == last ? 'Last used' : null,
          onSelected: () => openHost(hostId, mode: mode),
        ),
    ];
  }

  void openSftpHere() {
    final pane = _ref.read(workbenchProvider).focusedPane;
    final content = pane?.content;
    if (content is! SshTerminalContent) {
      unawaited(newSftp(placement: PanePlacement.splitRight));
      return;
    }
    final cwd = _ref.read(terminalSessionsProvider)[pane!.id]?.cwd.value;
    _bench.openPane(
      SftpContent(
        left: SftpSide(
          hostId: content.hostId,
          path: cwd ?? content.directory ?? '~',
        ),
      ),
      placement: PanePlacement.splitRight,
    );
  }

  void _split(SplitAxis axis) {
    final focused = _ref.read(workbenchProvider).focusedPane;
    final placement = axis == SplitAxis.horizontal
        ? PanePlacement.splitRight
        : PanePlacement.splitDown;
    final content = focused?.content;
    switch (content) {
      case SshTerminalContent(:final hostId):
        _bench.openPane(
          SshTerminalContent(hostId: hostId),
          placement: placement,
        );
      case LocalTerminalContent():
        _bench.openPane(const LocalTerminalContent(), placement: placement);
      case SftpContent():
        _bench.openPane(content, placement: placement);
      case LogTailContent():
      case null:
        unawaited(newSession(placement: placement));
    }
  }

  void zoom(double? delta, {String? paneId}) {
    final state = _ref.read(workbenchProvider);
    final id = paneId ?? state.focusedPane?.id;
    final pane = id == null ? null : state.locate(id)?.pane;
    if (pane == null) return;
    final fallback = _ref.read(settingsProvider).terminalFontSize;
    if (delta == null) {
      _bench.setPaneFontSize(pane.id, null);
      return;
    }
    final next = WgTerminalZoom.clamp((pane.fontSize ?? fallback) + delta);
    _bench.setPaneFontSize(pane.id, next == fallback ? null : next);
  }

  Future<void> _newWorkspace() async {
    final context = _context;
    if (context == null) return;
    final name = await showTextPrompt(
      context,
      title: 'New workspace',
      label: 'Name',
      confirm: 'Create workspace',
    );
    if (name != null) _bench.createWorkspace(name);
  }

  Future<void> _renameWorkspace() async {
    final context = _context;
    final workspace = _ref.read(workbenchProvider).activeWorkspace;
    if (context == null || workspace == null) return;
    final name = await showTextPrompt(
      context,
      title: 'Rename workspace',
      label: 'Name',
      initial: workspace.name,
      confirm: 'Rename',
    );
    if (name != null) _bench.renameWorkspace(workspace.id, name);
  }

  Future<void> _saveLayout() async {
    final context = _context;
    if (context == null ||
        (_ref.read(workbenchProvider).activeTab?.isEmpty ?? true)) {
      return;
    }
    final name = await showTextPrompt(
      context,
      title: 'Save layout as',
      label: 'Name',
      confirm: 'Save layout',
    );
    if (name != null) await _bench.saveActiveTabAs(name);
  }

  Future<void> _openGroup() async {
    final context = _context;
    if (context == null) return;
    final catalog = _ref.read(hostsProvider).value;
    if (catalog == null) return;
    final group = await showGroupPicker(context, catalog);
    if (group == null) return;
    openHostsInGrid(group.hostIds, title: group.name);
  }

  void openHostsInGrid(List<String> hostIds, {String? title}) {
    if (hostIds.isEmpty) return;
    _go(Routes.workbench);
    _bench.openTabWith([
      for (final id in hostIds) SshTerminalContent(hostId: id),
    ], title: title);
  }

  List<AppCommand> commands() {
    final keys = _ref.read(shortcutMapProvider);
    final state = _ref.read(workbenchProvider);
    AppCommand c(
      String id,
      VoidCallback run, {
      IconData? icon,
      String? title,
    }) {
      final entry = _paletteEntries[id]!;
      return AppCommand(
        id: id,
        title: title ?? entry.title,
        category: entry.category,
        run: run,
        shortcut: keys[id],
        icon: icon,
        keywords: entry.keywords,
      );
    }

    return [
      c(
        'palette.open', () => _ref.read(paletteProvider.notifier).toggle(PaletteMode.commands),
        icon: WgIcons.search,
      ),
      c(
        'palette.switcher', () => _ref.read(paletteProvider.notifier).toggle(PaletteMode.switcher),
        icon: WgIcons.terminal,
      ),
      c(
        'session.new', () => unawaited(newSession()),
        icon: WgIcons.terminal,
      ),
      if (PlatformInfo.supportsLocalTerminal)
        c(
          'session.local', () {
            _go(Routes.workbench);
            _bench.openPane(const LocalTerminalContent());
          },
          icon: WgIcons.monitor,
        ),
      c(
        'sftp.new', () => unawaited(newSftp()),
        icon: WgIcons.folder,
      ),
      c(
        'sftp.dual', () {
          _go(Routes.workbench);
          _bench.openPane(
            const SftpContent(left: SftpSide(), right: SftpSide()),
          );
        },
        icon: WgIcons.arrowLeftRight,
      ),
      c(
        'sftp.here', toggleFiles,
        icon: WgIcons.filesPanel,
      ),
      c(
        'sftp.split', openSftpHere,
        icon: WgIcons.folderOpen,
      ),
      c(
        'pane.splitRight', () => _split(SplitAxis.horizontal),
        icon: WgIcons.splitHorizontal,
      ),
      c(
        'pane.splitDown', () => _split(SplitAxis.vertical),
        icon: WgIcons.splitVertical,
      ),
      c(
        'pane.close', _bench.closeFocusedPane,
        icon: WgIcons.close,
      ),
      c(
        'pane.maximize', _bench.toggleMaximize,
        icon: WgIcons.maximize,
      ),
      c(
        'pane.focusLeft', () => _bench.focusDirection(PaneDirection.left),
      ),
      c(
        'pane.focusRight', () => _bench.focusDirection(PaneDirection.right),
      ),
      c(
        'pane.focusUp', () => _bench.focusDirection(PaneDirection.up),
      ),
      c(
        'pane.focusDown', () => _bench.focusDirection(PaneDirection.down),
      ),
      c(
        'pane.growLeft', () => _bench.resizeFocused(PaneDirection.left),
      ),
      c(
        'pane.growRight', () => _bench.resizeFocused(PaneDirection.right),
      ),
      c(
        'pane.growUp', () => _bench.resizeFocused(PaneDirection.up),
      ),
      c(
        'pane.growDown', () => _bench.resizeFocused(PaneDirection.down),
      ),
      c(
        'pane.swapRight', () => _bench.swapWithNeighbor(PaneDirection.right),
        icon: WgIcons.swap,
      ),
      c(
        'pane.swapDown', () => _bench.swapWithNeighbor(PaneDirection.down),
        icon: WgIcons.swap,
      ),
      c('pane.toTab', () {
        final id = state.activeTab?.focusedPaneId;
        if (id != null) _bench.movePaneToTab(id);
      }),
      for (final preset in LayoutPresetKind.values)
        c(
          'layout.${preset.name}', () => _bench.applyPreset(preset),
          icon: WgIcons.layout,
        ),
      c(
        'layout.save', () => unawaited(_saveLayout()),
        icon: WgIcons.save,
      ),
      c('layout.open', () {
        final context = _context;
        if (context != null) unawaited(showSavedLayouts(context));
      }, icon: WgIcons.history),
      c(
        'tab.next', () => _bench.cycleTab(1),
      ),
      c(
        'tab.previous', () => _bench.cycleTab(-1),
      ),
      c(
        'workspace.new', () => unawaited(_newWorkspace()),
        icon: WgIcons.workspace,
      ),
      c(
        'workspace.rename', () => unawaited(_renameWorkspace()),
        icon: WgIcons.edit,
      ),
      for (final (index, workspace) in state.workspaces.take(9).indexed)
        c(
          'workspace.${index + 1}', () {
            _go(Routes.workbench);
            _bench.switchWorkspaceAt(index);
          },
          icon: WgIcons.workspace,
          title: 'Workspace: ${workspace.name}',
        ),
      c(
        'broadcast.toggle', _bench.toggleBroadcastForTab,
        icon: WgIcons.broadcast,
      ),
      c(
        'broadcast.clear', () => _bench.setBroadcast(const {}),
        icon: WgIcons.broadcast,
      ),
      c(
        'group.open', () => unawaited(_openGroup()),
        icon: WgIcons.group,
      ),
      c(
        'multiExec.open', () => _go(Routes.multiExec),
        icon: WgIcons.multiExec,
      ),
      c('snippets.run', () {
        final context = _context;
        if (context != null) unawaited(showSnippetRunner(context));
      }, icon: WgIcons.snippet),
      c(
        'nav.hosts', () => _go(Routes.hosts),
        icon: WgIcons.server,
      ),
      c(
        'nav.keys', () => _go(Routes.keys),
        icon: WgIcons.key,
      ),
      c(
        'transfers.open', () => _go(Routes.transfers),
        icon: WgIcons.transfer,
      ),
      c(
        'nav.forwards', () => _go(Routes.forwards),
        icon: WgIcons.forward,
      ),
      c(
        'nav.snippets', () => _go(Routes.snippets),
        icon: WgIcons.snippet,
      ),
      c(
        'nav.workbench', () => _go(Routes.workbench),
        icon: WgIcons.terminal,
      ),
      c(
        'settings.open', () => _go(Routes.settings),
        icon: WgIcons.settings,
      ),
      c(
        'nav.mcp', () => _go(Routes.mcpActivity),
        icon: WgIcons.bot,
      ),
      c('sidebar.toggle', () {
        final collapsed = _ref.read(settingsProvider).sidebarCollapsed;
        _ref.read(settingsProvider.notifier).update({
          'sidebarCollapsed': !collapsed,
        });
      }, icon: WgIcons.sidebar),
      c(
        'terminal.zoomIn', () => zoom(WgTerminalZoom.step),
        icon: WgIcons.zoomIn,
      ),
      c(
        'terminal.zoomOut', () => zoom(-WgTerminalZoom.step),
        icon: WgIcons.zoomOut,
      ),
      c(
        'terminal.zoomReset', () => zoom(null),
      ),
      if (_ref.read(settingsProvider).appLock)
        c(
          'app.lock', () => _ref.read(appLockProvider.notifier).lock(),
          icon: WgIcons.lock,
        ),
    ];
  }
}

final commandRegistryProvider = Provider<CommandRegistry>(CommandRegistry.new);
