import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/workspace/presentation/pane_builder.dart';
import 'package:warpgate/features/workspace/presentation/widgets/phone_session_strip.dart';
import 'package:warpgate/features/workspace/presentation/widgets/workbench_empty_state.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/features/workspace/domain/workspace.dart';

class PhoneWorkbench extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PhoneWorkbench> createState() => PhoneWorkbenchState();
}

class PhoneWorkbenchState extends ConsumerState<PhoneWorkbench> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = ref.watch(workbenchProvider);
    final workspace = bench.activeWorkspace;
    final panes = [
      for (final tab in workspace?.tabs ?? const <WorkspaceTab>[])
        for (final id in tab.paneOrder) (tab: tab, pane: tab.panes[id]!),
    ];
    if (panes.isEmpty) return const WorkbenchEmptyState();
    final focusedId = bench.activeTab?.focusedPaneId;
    final current = panes
        .indexWhere((item) => item.pane.id == focusedId)
        .clamp(0, panes.length - 1);
    if (_pages.hasClients && _pages.page?.round() != current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(current);
      });
    }
    return Column(
      children: [
        PhoneSessionStrip(
          panes: [for (final item in panes) item.pane],
          current: current,
          onSelect: (index) {
            _pages.animateToPage(
              index,
              duration: context.motion.medium,
              curve: context.motion.curve,
            );
          },
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: panes.length,
            onPageChanged: (index) {
              final item = panes[index];
              ref.read(workbenchProvider.notifier)
                ..selectTab(item.tab.id)
                ..focusPane(item.pane.id);
            },
            itemBuilder: (context, index) => buildPane(panes[index].pane),
          ),
        ),
      ],
    );
  }
}
