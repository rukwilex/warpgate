import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/domain/app_command.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/sftp/application/file_places.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

sealed class _Choice {
  const new();
}

class _CommandChoice extends _Choice {
  const new(this.command);

  final AppCommand command;
}

class _PaneChoice extends _Choice {
  const new(this.paneId);

  final String paneId;
}

class _HostChoice extends _Choice {
  const new(this.host, this.mode);

  final Host host;
  final HostOpenMode mode;
}

class PaletteOverlay extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(paletteProvider);
    return Stack(
      children: [
        child,
        if (mode != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => ref.read(paletteProvider.notifier).close(),
              child: Semantics(
                label: 'Close command palette',
                button: true,
                child: ColoredBox(color: context.colors.scrim),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: WgFloatingPanel(
                child: _Palette(key: ValueKey(mode), mode: mode),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Palette extends ConsumerWidget {
  const new({required this.mode, super.key});

  final PaletteMode mode;

  List<WgSearchItem<_Choice>> _sessions(WidgetRef ref, String query) {
    final bench = ref.watch(workbenchProvider);
    final catalog = ref.watch(hostsProvider).value ?? const HostsCatalog();
    final sessions = ref.read(terminalSessionsProvider);
    final links = ref.watch(hostLinksProvider);
    final q = query.toLowerCase();
    final items = <WgSearchItem<_Choice>>[];
    for (final location in bench.allPanes) {
      final content = location.pane.content;
      final hostId = content.hostId;
      final title = switch (content) {
        SshTerminalContent() => catalog.host(hostId)?.label ?? 'Removed host',
        LocalTerminalContent() => 'Local terminal',
        SftpContent(:final left) =>
          'Files · ${left.isLocal ? 'This device' : catalog.host(left.hostId)?.label}',
        LogTailContent(:final path) => 'tail $path',
      };
      final where =
          '${location.workspace.name} · ${location.tab.title ?? 'tab ${location.workspace.tabs.indexOf(location.tab) + 1}'}';
      if (q.isNotEmpty && !'$title $where'.toLowerCase().contains(q)) continue;
      final state =
          sessions[location.pane.id]?.status.value.state ??
          (hostId == null
              ? LinkState.connected
              : links[hostId]?.state ?? LinkState.idle);
      items.add(
        WgSearchItem(
          value: _PaneChoice(location.pane.id),
          title: title,
          subtitle: where,
          section: 'Open sessions',
          leading: WgStatusDot(state: state.dot, subject: title),
        ),
      );
    }
    return items;
  }

  List<WgSearchItem<_Choice>> _items(WidgetRef ref, String query) {
    if (mode == PaletteMode.switcher) {
      final open = _sessions(ref, query);
      final catalog = ref.watch(hostsProvider).value ?? const HostsCatalog();
      final registry = ref.read(commandRegistryProvider);
      final q = query.toLowerCase();
      return [
        ...open,
        for (final host in catalog.hosts)
          if (q.isEmpty ||
              host.label.toLowerCase().contains(q) ||
              host.address.toLowerCase().contains(q))
            for (final mode in [
              registry.lastOpenMode(host.id),
              if (q.isNotEmpty)
                ...HostOpenMode.values.where(
                  (mode) => mode != registry.lastOpenMode(host.id),
                ),
            ])
              WgSearchItem(
                value: _HostChoice(host, mode),
                title: host.label,
                subtitle: host.endpoint,
                meta: mode.label,
                section: 'Open a host',
                leading: Icon(switch (mode) {
                  HostOpenMode.terminal => WgIcons.terminal,
                  HostOpenMode.files => WgIcons.folder,
                  HostOpenMode.both => WgIcons.filesPanel,
                }),
              ),
      ];
    }
    final commands = ref.read(commandRegistryProvider).commands();
    final scored = [
      for (final command in commands)
        if (command.score(query) > 0) (command, command.score(query)),
    ];
    if (query.isNotEmpty) {
      mergeSort(scored, compare: (a, b) => b.$2.compareTo(a.$2));
    }
    return [
      for (final (command, _) in scored.where(
        (item) => item.$1.id != 'palette.open',
      ))
        WgSearchItem(
          value: _CommandChoice(command),
          title: command.title,
          meta: command.shortcut == null ? command.category.label : null,
          shortcut: command.shortcut,
          leading: command.icon == null ? null : Icon(command.icon),
        ),
      if (query.isNotEmpty) ..._sessions(ref, query),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.read(paletteProvider.notifier);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: mode == PaletteMode.commands
          ? 'Command palette'
          : 'Switch to session',
      explicitChildNodes: true,
      child: WgSearchList<_Choice>(
        placeholder: mode == PaletteMode.commands
            ? 'Type a command or a session'
            : 'Session or host',
        onCancel: palette.close,
        items: (query) => _items(ref, query),
        onSelected: (choice) {
          palette.close();
          switch (choice) {
            case _CommandChoice(:final command):
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => command.run(),
              );
            case _PaneChoice(:final paneId):
              GoRouter.of(context).go(Routes.workbench);
              ref.read(workbenchProvider.notifier).reveal(paneId);
            case _HostChoice(:final host, :final mode):
              ref.read(commandRegistryProvider).openHost(host.id, mode: mode);
          }
        },
      ),
    );
  }
}
