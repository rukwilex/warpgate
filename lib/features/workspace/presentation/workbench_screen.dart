import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/workspace/presentation/layout_view.dart';
import 'package:warpgate/features/workspace/presentation/pane_builder.dart';
import 'package:warpgate/features/workspace/presentation/widgets/phone_workbench.dart';
import 'package:warpgate/features/workspace/presentation/widgets/workbench_empty_state.dart';
import 'package:warpgate/features/workspace/presentation/widgets/workbench_tab_strip.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';

class WorkbenchScreen extends ConsumerWidget {
  const new({super.key, this.phone = false});

  final bool phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bench = ref.watch(workbenchProvider);
    final workspace = bench.activeWorkspace;
    final tab = workspace?.activeTab;
    final tabsInTitleBar = ref.watch(windowChromeProvider).custom;
    if (phone) return const PhoneWorkbench();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!tabsInTitleBar) const WorkbenchTabStrip(),
        Expanded(
          child: tab == null || tab.isEmpty
              ? const WorkbenchEmptyState()
              : LayoutView(
                  key: ValueKey(tab.id),
                  tab: tab,
                  paneBuilder: (context, paneId) =>
                      buildPane(tab.panes[paneId]!),
                ),
        ),
      ],
    );
  }
}
