import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/core/util/ids.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/connection/presentation/link_dot.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/hosts/presentation/host_editor.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/shell/presentation/prompts.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

class HostsScreen extends ConsumerStatefulWidget {
  const new({super.key, this.intent});

  final Object? intent;

  @override
  ConsumerState<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends ConsumerState<HostsScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_handleIntent(widget.intent)),
    );
  }

  @override
  void didUpdateWidget(HostsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.intent != oldWidget.intent) {
      unawaited(_handleIntent(widget.intent));
    }
  }

  Future<void> _handleIntent(Object? intent) async {
    if (!mounted || intent == null) return;
    if (intent == 'new') {
      await showHostEditor(context);
    } else if (intent == 'import') {
      await _import();
    } else if (intent is String) {
      final catalog = await ref.read(hostsProvider.future);
      final host = catalog.host(intent);
      if (host != null && mounted) await showHostEditor(context, host: host);
    }
  }

  Future<void> _import() async {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final file = home == null ? null : File('$home/.ssh/config');
    if (file == null || !file.existsSync()) {
      if (mounted) {
        showWgToast(context, 'No ~/.ssh/config found on this device');
      }
      return;
    }
    final count = await ref
        .read(hostsProvider.notifier)
        .importSshConfig(await file.readAsString());
    if (!mounted) return;
    showWgToast(
      context,
      count == 0
          ? 'Nothing new in ~/.ssh/config'
          : 'Imported ${Format.plural(count, 'host')}. Check keys before connecting',
    );
  }

  Future<void> _newGroup() async {
    final name = await showTextPrompt(
      context,
      title: 'New group',
      label: 'Name',
      confirm: 'Create group',
    );
    if (name != null) await ref.read(hostsProvider.notifier).addGroup(name);
  }

  Future<void> _delete(Host host) async {
    final ok = await showWgConfirm(
      context,
      title: 'Delete ${host.label}?',
      message: 'Its saved password is removed too. Open panes on this host will stop working. Keys stay in Keys.',
      confirmLabel: 'Delete host',
      destructive: true,
    );
    if (ok) await ref.read(hostsProvider.notifier).deleteHost(host.id);
  }

  void _open(
    PaneContent content, {
    PanePlacement placement = PanePlacement.newTab,
  }) {
    GoRouter.of(context).go(Routes.workbench);
    ref
        .read(workbenchProvider.notifier)
        .openPane(content, placement: placement);
  }

  List<WgMenuEntry> _hostMenu(Host host) => [
    WgMenuEntry(
      label: 'Open terminal',
      icon: WgIcons.terminal,
      onSelected: () => _open(SshTerminalContent(hostId: host.id)),
    ),
    WgMenuEntry(
      label: 'Browse files',
      icon: WgIcons.folder,
      onSelected: () => _open(
        SftpContent(
          left: SftpSide(hostId: host.id, path: '~'),
        ),
      ),
    ),
    WgMenuEntry(
      label: 'Tail a log file',
      icon: WgIcons.scrollText,
      onSelected: () async {
        final path = await showTextPrompt(
          context,
          title: 'Tail a log on ${host.label}',
          label: 'File',
          initial: '/var/log/syslog',
          confirm: 'Tail',
          mono: true,
        );
        if (path != null) _open(LogTailContent(hostId: host.id, path: path));
      },
    ),
    WgMenuEntry(
      label: 'Edit',
      icon: WgIcons.edit,
      onSelected: () => unawaited(showHostEditor(context, host: host)),
    ),
    WgMenuEntry(
      label: 'Duplicate',
      icon: WgIcons.copy,
      onSelected: () => unawaited(
        ref
            .read(hostsProvider.notifier)
            .saveHost(
              Host.fromJson({
                ...host.toJson(),
                'id': Ids.next(),
                'label': '${host.label} copy',
              }),
            ),
      ),
    ),
    const WgMenuEntry.divider(),
    WgMenuEntry(
      label: 'Delete',
      icon: WgIcons.trash,
      destructive: true,
      onSelected: () => unawaited(_delete(host)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(hostsProvider);
    final links = ref.watch(hostLinksProvider);
    final colors = context.colors;
    final registry = ref.read(commandRegistryProvider);
    final catalog = async.value;
    final q = _query.toLowerCase();
    bool matches(Host host) =>
        q.isEmpty ||
        host.label.toLowerCase().contains(q) ||
        host.address.toLowerCase().contains(q) ||
        host.username.toLowerCase().contains(q) ||
        host.tags.any((tag) => tag.toLowerCase().contains(q));

    Widget hostRow(Host host) {
      final link = links[host.id];
      final state = link?.state ?? LinkState.idle;
      final meta = [
        if (host.jumpHostId != null)
          'via ${catalog?.host(host.jumpHostId)?.label ?? 'jump'}',
        if (host.tmuxPersistence) 'tmux',
        if (host.mcpPermission != McpPermission.off)
          'Claude: ${host.mcpPermission.label.toLowerCase()}',
        ...host.tags.map((tag) => '#$tag'),
      ].join('  ');
      return WgListRow(
        title: host.label,
        subtitle: host.endpoint,
        meta: meta.isEmpty ? null : meta,
        leading: WgStatusDot(state: state.dot, subject: host.label),
        semanticLabel:
            '${host.label}, ${host.endpoint}, ${state.dot.label.toLowerCase()}',
        onPressed: () => _open(SshTerminalContent(hostId: host.id)),
        onSecondaryTapDown: (details) => unawaited(
          showWgMenu(
            context,
            position: details.globalPosition,
            entries: _hostMenu(host),
          ),
        ),
        onLongPress: PlatformInfo.isMobile
            ? () => unawaited(
                showWgMenu(
                  context,
                  position: MediaQuery.sizeOf(context).center(Offset.zero),
                  entries: _hostMenu(host),
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (link?.state == LinkState.dropped && link?.message != null)
              Tooltip(
                message: link!.message,
                child: Icon(
                  WgIcons.warning,
                  size: context.sizes.icon,
                  color: colors.negative,
                  semanticLabel: link.message,
                ),
              ),
            WgIconButton(
              icon: WgIcons.folder,
              label: 'Browse files on ${host.label}',
              compact: true,
              onPressed: () => _open(
                SftpContent(
                  left: SftpSide(hostId: host.id, path: '~'),
                ),
              ),
            ),
            WgMenuButton(
              icon: WgIcons.more,
              label: 'More for ${host.label}',
              entries: () => _hostMenu(host),
            ),
          ],
        ),
      );
    }

    final Widget body;
    if (catalog == null) {
      body = const WgSkeletonList(rows: 8, label: 'Loading hosts');
    } else if (catalog.hosts.isEmpty) {
      body = Padding(
        padding: EdgeInsets.only(top: context.space.huge),
        child: WgEmptyState(
          icon: WgIcons.server,
          title: 'No hosts yet',
          body: 'A host is a saved server: address, user and how to sign in. Add one, or import the ones in your SSH config.',
          action: WgButton.primary(
            label: 'Add host',
            icon: WgIcons.plus,
            onPressed: () => unawaited(showHostEditor(context)),
          ),
          secondary: PlatformInfo.supportsSshConfigImport
              ? WgButton.ghost(
                  label: 'Import ~/.ssh/config',
                  onPressed: () => unawaited(_import()),
                )
              : null,
        ),
      );
    } else {
      final ungrouped = catalog.ungrouped.where(matches).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WgTextField(
            placeholder: 'Filter hosts',
            leadingIcon: WgIcons.search,
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          if (ungrouped.isNotEmpty) ...[
            const WgSectionLabel('Ungrouped'),
            for (final host in ungrouped) hostRow(host),
          ],
          for (final group in catalog.groups) ...[
            WgSectionLabel(
              group.name,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WgIconButton(
                    icon: WgIcons.grid,
                    label: 'Open all of ${group.name} in a grid',
                    compact: true,
                    onPressed: catalog.inGroup(group.id).isEmpty
                        ? null
                        : () => registry.openHostsInGrid([
                            for (final host in catalog.inGroup(group.id))
                              host.id,
                          ], title: group.name),
                  ),
                  WgMenuButton(
                    icon: WgIcons.more,
                    label: 'More for group ${group.name}',
                    entries: () => [
                      WgMenuEntry(
                        label: 'Rename group',
                        icon: WgIcons.edit,
                        onSelected: () async {
                          final name = await showTextPrompt(
                            context,
                            title: 'Rename group',
                            label: 'Name',
                            initial: group.name,
                            confirm: 'Rename',
                          );
                          if (name != null) {
                            await ref
                                .read(hostsProvider.notifier)
                                .renameGroup(group.id, name);
                          }
                        },
                      ),
                      WgMenuEntry(
                        label: 'Delete group',
                        icon: WgIcons.trash,
                        destructive: true,
                        onSelected: () => unawaited(
                          ref
                              .read(hostsProvider.notifier)
                              .deleteGroup(group.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (catalog.inGroup(group.id).isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.space.sm),
                child: Text(
                  "No hosts in this group. Pick it in a host's settings.",
                  style: context.type.caption,
                ),
              ),
            for (final host in catalog.inGroup(group.id).where(matches))
              hostRow(host),
          ],
        ],
      );
    }
    return WgPage(
      title: 'Hosts',
      subtitle: catalog == null
          ? null
          : Format.plural(catalog.hosts.length, 'host'),
      actions: [
        if (PlatformInfo.supportsSshConfigImport &&
            (catalog?.hosts.isNotEmpty ?? false))
          WgButton.ghost(
            label: 'Import ~/.ssh/config',
            icon: WgIcons.import,
            onPressed: () => unawaited(_import()),
          ),
        WgButton(
          label: 'New group',
          icon: WgIcons.group,
          onPressed: () => unawaited(_newGroup()),
        ),
        if (catalog?.hosts.isNotEmpty ?? false)
          WgButton.primary(
            label: 'Add host',
            icon: WgIcons.plus,
            onPressed: () => unawaited(showHostEditor(context)),
          ),
      ],
      child: body,
    );
  }
}
