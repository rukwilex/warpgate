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

typedef EndpointPick = ({Host? host});

typedef GroupPick = ({String name, List<String> hostIds});

List<WgSearchItem<Host>> hostItems(WidgetRef ref, String query) {
  final catalog = ref.watch(hostsProvider).value ?? const HostsCatalog();
  final links = ref.watch(hostLinksProvider);
  final q = query.toLowerCase();
  return [
    for (final host in catalog.hosts)
      if (q.isEmpty ||
          host.label.toLowerCase().contains(q) ||
          host.address.toLowerCase().contains(q) ||
          host.tags.any((tag) => tag.toLowerCase().contains(q)) ||
          (catalog.group(host.groupId)?.name.toLowerCase().contains(q) ??
              false))
        WgSearchItem(
          value: host,
          title: host.label,
          subtitle: host.endpoint,
          leading: WgStatusDot(
            state: (links[host.id]?.state ?? LinkState.idle).dot,
            subject: host.label,
          ),
        ),
  ];
}

Future<Host?> showHostPicker(
  BuildContext context, {
  required String title,
}) async {
  final pick = await _show<Host?>(context, title: title, allowLocal: false);
  return pick;
}

Future<EndpointPick?> showEndpointPicker(
  BuildContext context, {
  required String title,
}) async {
  final result = await _show<Object?>(context, title: title, allowLocal: true);
  if (result == null) return null;
  if (result is Host) return (host: result);
  return (host: null);
}

class _LocalChoice {
  const new();
}

Future<T?> _show<T>(
  BuildContext context, {
  required String title,
  required bool allowLocal,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: context.colors.scrim,
  transitionDuration: context.motion.fast,
  pageBuilder: (dialogContext, _, _) => WgFloatingPanel(
    child: Consumer(
      builder: (context, ref, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.space.lg,
              context.space.md,
              context.space.lg,
              0,
            ),
            child: Semantics(
              header: true,
              child: Text(title, style: context.type.label),
            ),
          ),
          WgSearchList<Object?>(
            placeholder: 'Host, address or tag',
            emptyTitle: 'No saved hosts match',
            emptyBody: 'Add the server in Hosts, then open it from here.',
            emptyAction: WgButton(
              label: 'Add host',
              icon: WgIcons.plus,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                GoRouter.of(context).go(Routes.hosts, extra: 'new');
              },
            ),
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSelected: (value) =>
                Navigator.of(dialogContext)
                    .pop(value is _LocalChoice ? const _LocalChoice() : value),
            items: (query) => [
              if (allowLocal &&
                  (query.isEmpty ||
                      'this device local'.contains(query.toLowerCase())))
                const WgSearchItem<Object?>(
                  value: _LocalChoice(),
                  title: 'This device',
                  subtitle: 'Local files',
                  leading: Icon(WgIcons.monitor),
                ),
              for (final item in hostItems(ref, query))
                WgSearchItem<Object?>(
                  value: item.value,
                  title: item.title,
                  subtitle: item.subtitle,
                  leading: item.leading,
                ),
            ],
          ),
        ],
      ),
    ),
  ),
);

Future<GroupPick?> showGroupPicker(BuildContext context, HostsCatalog catalog) {
  final options = <GroupPick>[
    for (final group in catalog.groups)
      (
        name: group.name,
        hostIds: [for (final host in catalog.inGroup(group.id)) host.id],
      ),
    for (final tag in catalog.tags)
      (
        name: '#$tag',
        hostIds: [for (final host in catalog.withTag(tag)) host.id],
      ),
  ].where((option) => option.hostIds.isNotEmpty).toList();
  return showGeneralDialog<GroupPick>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: context.colors.scrim,
    pageBuilder: (dialogContext, _, _) => WgFloatingPanel(
      child: WgSearchList<GroupPick>(
        placeholder: 'Group or tag',
        emptyTitle: 'No groups or tags yet',
        emptyBody:
            'Give hosts a group or a tag in Hosts to open them together.',
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSelected: (value) => Navigator.of(dialogContext).pop(value),
        items: (query) => [
          for (final option in options)
            if (option.name.toLowerCase().contains(query.toLowerCase()))
              WgSearchItem(
                value: option,
                title: option.name,
                meta: '${option.hostIds.length} hosts',
                leading: Icon(
                  option.name.startsWith('#') ? WgIcons.tag : WgIcons.group,
                ),
              ),
        ],
      ),
    ),
  );
}
