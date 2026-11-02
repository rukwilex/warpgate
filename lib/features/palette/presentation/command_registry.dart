import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/shortcuts/shortcut_codec.dart';
import 'package:warpgate/design_system/components/wg_icons.dart';
import 'package:warpgate/features/hosts/presentation/host_picker.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/domain/app_command.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/prompts.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/snippets/presentation/snippet_runner.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/saved_layouts_dialog.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

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

  final Ref _ref;

  BuildContext? get _context => rootNavigatorKey.currentContext;

  WorkbenchController get _bench => _ref.read(workbenchProvider.notifier);

  void _go(String route) {
    _ref.read(routerProvider).go(route);
  }

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

  void _zoom(double delta) {
    final size = (_ref.read(settingsProvider).terminalFontSize + delta).clamp(
      8,
      32,
    );
    _ref.read(settingsProvider.notifier).update({'terminalFontSize': size});
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
      String title,
      CommandCategory category,
      VoidCallback run, {
      IconData? icon,
      List<String> keywords = const [],
    }) => AppCommand(
      id: id,
      title: title,
      category: category,
      run: run,
      shortcut: keys[id],
      icon: icon,
      keywords: keywords,
    );
    return [
      c(
        'palette.open',
        'Command palette',
        CommandCategory.general,
        () => _ref.read(paletteProvider.notifier).toggle(PaletteMode.commands),
        icon: WgIcons.search,
      ),
      c(
        'palette.switcher',
        'Switch to session',
        CommandCategory.general,
        () => _ref.read(paletteProvider.notifier).toggle(PaletteMode.switcher),
        icon: WgIcons.terminal,
        keywords: const ['quick', 'jump'],
      ),
      c(
        'session.new',
        'New terminal',
        CommandCategory.sessions,
        () => unawaited(newSession()),
        icon: WgIcons.terminal,
        keywords: const ['ssh', 'connect', 'tab'],
      ),
      if (PlatformInfo.supportsLocalTerminal)
        c(
          'session.local',
          'New local terminal',
          CommandCategory.sessions,
          () {
            _go(Routes.workbench);
            _bench.openPane(const LocalTerminalContent());
          },
          icon: WgIcons.monitor,
          keywords: const ['shell'],
        ),
      c(
        'sftp.new',
        'Browse files',
        CommandCategory.files,
        () => unawaited(newSftp()),
        icon: WgIcons.folder,
        keywords: const ['sftp'],
      ),
      c(
        'sftp.dual',
        'Two-pane file browser',
        CommandCategory.files,
        () {
          _go(Routes.workbench);
          _bench.openPane(
            const SftpContent(left: SftpSide(), right: SftpSide()),
          );
        },
        icon: WgIcons.arrowLeftRight,
        keywords: const ['dual', 'sftp', 'copy between'],
      ),
      c(
        'sftp.here',
        'Open files at terminal folder',
        CommandCategory.files,
        openSftpHere,
        icon: WgIcons.folderOpen,
        keywords: const ['sftp', 'cwd'],
      ),
      c(
        'pane.splitRight',
        'Split right',
        CommandCategory.panes,
        () => _split(SplitAxis.horizontal),
        icon: WgIcons.splitHorizontal,
      ),
      c(
        'pane.splitDown',
        'Split down',
        CommandCategory.panes,
        () => _split(SplitAxis.vertical),
        icon: WgIcons.splitVertical,
      ),
      c(
        'pane.close',
        'Close pane',
        CommandCategory.panes,
        _bench.closeFocusedPane,
        icon: WgIcons.close,
      ),
      c(
        'pane.maximize',
        'Maximize or restore pane',
        CommandCategory.panes,
        _bench.toggleMaximize,
        icon: WgIcons.maximize,
        keywords: const ['zoom'],
      ),
      c(
        'pane.focusLeft',
        'Focus pane on the left',
        CommandCategory.panes,
        () => _bench.focusDirection(PaneDirection.left),
      ),
      c(
        'pane.focusRight',
        'Focus pane on the right',
        CommandCategory.panes,
        () => _bench.focusDirection(PaneDirection.right),
      ),
      c(
        'pane.focusUp',
        'Focus pane above',
        CommandCategory.panes,
        () => _bench.focusDirection(PaneDirection.up),
      ),
      c(
        'pane.focusDown',
        'Focus pane below',
        CommandCategory.panes,
        () => _bench.focusDirection(PaneDirection.down),
      ),
      c(
        'pane.growLeft',
        'Move divider left',
        CommandCategory.panes,
        () => _bench.resizeFocused(PaneDirection.left),
        keywords: const ['resize'],
      ),
      c(
        'pane.growRight',
        'Move divider right',
        CommandCategory.panes,
        () => _bench.resizeFocused(PaneDirection.right),
        keywords: const ['resize'],
      ),
      c(
        'pane.growUp',
        'Move divider up',
        CommandCategory.panes,
        () => _bench.resizeFocused(PaneDirection.up),
        keywords: const ['resize'],
      ),
      c(
        'pane.growDown',
        'Move divider down',
        CommandCategory.panes,
        () => _bench.resizeFocused(PaneDirection.down),
        keywords: const ['resize'],
      ),
      c(
        'pane.swapRight',
        'Swap with pane on the right',
        CommandCategory.panes,
        () => _bench.swapWithNeighbor(PaneDirection.right),
        icon: WgIcons.swap,
      ),
      c(
        'pane.swapDown',
        'Swap with pane below',
        CommandCategory.panes,
        () => _bench.swapWithNeighbor(PaneDirection.down),
        icon: WgIcons.swap,
      ),
      c('pane.toTab', 'Move pane to new tab', CommandCategory.panes, () {
        final id = state.activeTab?.focusedPaneId;
        if (id != null) _bench.movePaneToTab(id);
      }),
      for (final preset in LayoutPresetKind.values)
        c(
          'layout.${preset.name}',
          'Layout: ${preset.label}',
          CommandCategory.panes,
          () => _bench.applyPreset(preset),
          icon: WgIcons.layout,
          keywords: const ['preset', 'arrange'],
        ),
      c(
        'layout.save',
        'Save layout as…',
        CommandCategory.workspaces,
        () => unawaited(_saveLayout()),
        icon: WgIcons.save,
        keywords: const ['session', 'preset'],
      ),
      c('layout.open', 'Open saved layout…', CommandCategory.workspaces, () {
        final context = _context;
        if (context != null) unawaited(showSavedLayouts(context));
      }, icon: WgIcons.history),
      c(
        'tab.next',
        'Next tab',
        CommandCategory.workspaces,
        () => _bench.cycleTab(1),
      ),
      c(
        'tab.previous',
        'Previous tab',
        CommandCategory.workspaces,
        () => _bench.cycleTab(-1),
      ),
      c(
        'workspace.new',
        'New workspace',
        CommandCategory.workspaces,
        () => unawaited(_newWorkspace()),
        icon: WgIcons.workspace,
      ),
      c(
        'workspace.rename',
        'Rename workspace',
        CommandCategory.workspaces,
        () => unawaited(_renameWorkspace()),
        icon: WgIcons.edit,
      ),
      for (final (index, workspace) in state.workspaces.take(9).indexed)
        c(
          'workspace.${index + 1}',
          'Workspace: ${workspace.name}',
          CommandCategory.workspaces,
          () {
            _go(Routes.workbench);
            _bench.switchWorkspaceAt(index);
          },
          icon: WgIcons.workspace,
        ),
      c(
        'broadcast.toggle',
        'Broadcast to all terminals in tab',
        CommandCategory.multi,
        _bench.toggleBroadcastForTab,
        icon: WgIcons.broadcast,
        keywords: const ['type', 'many', 'sync'],
      ),
      c(
        'broadcast.clear',
        'Stop broadcasting',
        CommandCategory.multi,
        () => _bench.setBroadcast(const {}),
        icon: WgIcons.broadcast,
      ),
      c(
        'group.open',
        'Open host group in grid',
        CommandCategory.multi,
        () => unawaited(_openGroup()),
        icon: WgIcons.group,
      ),
      c(
        'multiExec.open',
        'Run on many hosts',
        CommandCategory.multi,
        () => _go(Routes.multiExec),
        icon: WgIcons.multiExec,
        keywords: const ['exec', 'parallel'],
      ),
      c('snippets.run', 'Run snippet', CommandCategory.multi, () {
        final context = _context;
        if (context != null) unawaited(showSnippetRunner(context));
      }, icon: WgIcons.snippet),
      c(
        'nav.hosts',
        'Hosts',
        CommandCategory.navigation,
        () => _go(Routes.hosts),
        icon: WgIcons.server,
      ),
      c(
        'nav.keys',
        'Keys',
        CommandCategory.navigation,
        () => _go(Routes.keys),
        icon: WgIcons.key,
      ),
      c(
        'transfers.open',
        'Transfers',
        CommandCategory.navigation,
        () => _go(Routes.transfers),
        icon: WgIcons.transfer,
      ),
      c(
        'nav.forwards',
        'Port forwards',
        CommandCategory.navigation,
        () => _go(Routes.forwards),
        icon: WgIcons.forward,
      ),
      c(
        'nav.snippets',
        'Snippets',
        CommandCategory.navigation,
        () => _go(Routes.snippets),
        icon: WgIcons.snippet,
      ),
      c(
        'nav.workbench',
        'Sessions',
        CommandCategory.navigation,
        () => _go(Routes.workbench),
        icon: WgIcons.terminal,
      ),
      c(
        'settings.open',
        'Settings',
        CommandCategory.navigation,
        () => _go(Routes.settings),
        icon: WgIcons.settings,
      ),
      c(
        'nav.mcp',
        'Claude Code activity',
        CommandCategory.navigation,
        () => _go(Routes.mcpActivity),
        icon: WgIcons.bot,
      ),
      c('sidebar.toggle', 'Show or hide sidebar', CommandCategory.general, () {
        final collapsed = _ref.read(settingsProvider).sidebarCollapsed;
        _ref.read(settingsProvider.notifier).update({
          'sidebarCollapsed': !collapsed,
        });
      }, icon: WgIcons.sidebar),
      c(
        'terminal.zoomIn',
        'Larger terminal text',
        CommandCategory.general,
        () => _zoom(1),
        icon: WgIcons.zoomIn,
      ),
      c(
        'terminal.zoomOut',
        'Smaller terminal text',
        CommandCategory.general,
        () => _zoom(-1),
        icon: WgIcons.zoomOut,
      ),
      if (_ref.read(settingsProvider).appLock)
        c(
          'app.lock',
          'Lock Warpgate',
          CommandCategory.general,
          () => _ref.read(appLockProvider.notifier).lock(),
          icon: WgIcons.lock,
        ),
    ];
  }
}

final commandRegistryProvider = Provider<CommandRegistry>(CommandRegistry.new);
