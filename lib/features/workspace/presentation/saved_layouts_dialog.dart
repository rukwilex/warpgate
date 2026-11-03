import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/workspace/domain/workspace.dart';

Future<void> showSavedLayouts(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _SavedLayoutsDialog(),
);

class _SavedLayoutsDialog extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SavedLayoutsDialog> createState() =>
      _SavedLayoutsDialogState();
}

class _SavedLayoutsDialogState extends ConsumerState<_SavedLayoutsDialog> {
  late Future<List<SavedLayout>> _layouts = ref
      .read(workbenchProvider.notifier)
      .savedLayouts();

  @override
  Widget build(BuildContext context) => WgDialog(
    title: 'Saved layouts',
    actions: [
      WgButton.ghost(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
    child: FutureBuilder<List<SavedLayout>>(
      future: _layouts,
      builder: (context, snapshot) {
        final layouts = snapshot.data;
        if (layouts == null) return const WgSkeletonList(rows: 3);
        if (layouts.isEmpty) {
          return const WgEmptyState(
            icon: WgIcons.save,
            title: 'No saved layouts',
            body: 'Arrange a tab the way you like, then choose Save layout as… in the command palette.',
          );
        }
        return Column(
          children: [
            for (final layout in layouts)
              WgListRow(
                title: layout.name,
                subtitle:
                    '${Format.plural(layout.tab.panes.length, 'pane')} · ${Format.time(layout.savedAt)}',
                leading: const Icon(WgIcons.layout),
                trailing: WgIconButton(
                  icon: WgIcons.trash,
                  label: 'Delete ${layout.name}',
                  compact: true,
                  onPressed: () async {
                    await ref
                        .read(workbenchProvider.notifier)
                        .deleteSavedLayout(layout.id);
                    setState(
                      () => _layouts = ref
                          .read(workbenchProvider.notifier)
                          .savedLayouts(),
                    );
                  },
                ),
                onPressed: () {
                  ref.read(workbenchProvider.notifier).openSavedLayout(layout);
                  Navigator.of(context).pop();
                  GoRouter.of(context).go(Routes.workbench);
                },
              ),
          ],
        );
      },
    ),
  );
}
