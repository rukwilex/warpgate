import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/util/ids.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';
import 'package:warpgate/features/workspace/domain/workspace.dart';

enum PanePlacement { newTab, splitRight, splitDown, replaceFocused }

final initialWorkbenchProvider = Provider<WorkbenchState?>((ref) => null);

final workbenchProvider = NotifierProvider<WorkbenchController, WorkbenchState>(
  WorkbenchController.new,
);

class WorkbenchController extends Notifier<WorkbenchState> {
  static const collection = 'workbench';
  static const documentId = 'state';
  static const layoutsCollection = 'saved_layouts';
  static const resizeStep = 0.05;

  Timer? _saveTimer;

  @override
  WorkbenchState build() {
    ref.onDispose(() => _saveTimer?.cancel());
    final restored = ref.watch(initialWorkbenchProvider);
    final restore = ref.read(settingsProvider).restoreOnLaunch;
    if (restored != null && restored.workspaces.isNotEmpty && restore) {
      return restored;
    }
    final workspace = Workspace(id: Ids.next(), name: 'Main');
    return WorkbenchState(
      workspaces: [workspace],
      activeWorkspaceId: workspace.id,
    );
  }

  static Future<WorkbenchState?> load(DocumentStore store) async {
    final json = await store.get(collection, documentId);
    if (json == null) return null;
    try {
      return WorkbenchState.fromJson(json);
    } on Object {
      return null;
    }
  }

  @override
  set state(WorkbenchState value) {
    super.state = value;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(flush()),
    );
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await ref
        .read(documentStoreProvider)
        .put(collection, documentId, state.toJson());
  }

  Workspace get _workspace => state.activeWorkspace!;

  void _updateWorkspace(Workspace Function(Workspace workspace) change) {
    state = state.replaceWorkspace(change(_workspace));
  }

  void _updateTab(
    String tabId,
    WorkspaceTab Function(WorkspaceTab tab) change,
  ) {
    for (final workspace in state.workspaces) {
      final tab = workspace.tabs.firstWhereOrNull((item) => item.id == tabId);
      if (tab != null) {
        state = state.replaceWorkspace(workspace.replaceTab(change(tab)));
        return;
      }
    }
  }

  String createWorkspace(String name) {
    final workspace = Workspace(
      id: Ids.next(),
      name: name.trim().isEmpty ? 'Workspace' : name.trim(),
    );
    state = state.copyWith(
      workspaces: [...state.workspaces, workspace],
      activeWorkspaceId: () => workspace.id,
    );
    return workspace.id;
  }

  void renameWorkspace(String id, String name) {
    final workspace = state.workspaces.firstWhereOrNull(
      (item) => item.id == id,
    );
    if (workspace == null || name.trim().isEmpty) return;
    state = state.replaceWorkspace(workspace.copyWith(name: name.trim()));
  }

  void deleteWorkspace(String id) {
    if (state.workspaces.length <= 1) return;
    final remaining = state.workspaces.where((item) => item.id != id).toList();
    state = state.copyWith(
      workspaces: remaining,
      activeWorkspaceId: () => state.activeWorkspaceId == id
          ? remaining.first.id
          : state.activeWorkspaceId,
    );
  }

  void switchWorkspace(String id) {
    if (state.workspaces.any((item) => item.id == id)) {
      state = state.copyWith(activeWorkspaceId: () => id);
    }
  }

  void switchWorkspaceAt(int index) {
    if (index >= 0 && index < state.workspaces.length) {
      switchWorkspace(state.workspaces[index].id);
    }
  }

  void reveal(String paneId) {
    final location = state.locate(paneId);
    if (location == null) return;
    state = state
        .replaceWorkspace(
          location.workspace
              .copyWith(activeTabId: () => location.tab.id)
              .replaceTab(location.tab.copyWith(focusedPaneId: () => paneId)),
        )
        .copyWith(activeWorkspaceId: () => location.workspace.id);
  }

  PaneContent _prepare(PaneContent content) {
    if (content is SshTerminalContent && content.tmuxSession == null) {
      final host = ref.read(hostsProvider).value?.host(content.hostId);
      final useTmux = host?.tmuxPersistence ?? false;
      if (useTmux) {
        return SshTerminalContent(
          hostId: content.hostId,
          directory: content.directory,
          tmuxSession: 'wg-${Ids.short()}',
        );
      }
    }
    return content;
  }

  String openPane(
    PaneContent content, {
    PanePlacement placement = PanePlacement.newTab,
    PaneOrigin origin = PaneOrigin.user,
    String? workspaceId,
  }) {
    if (workspaceId != null) switchWorkspace(workspaceId);
    final pane = Pane(
      id: Ids.next(),
      content: _prepare(content),
      origin: origin,
    );
    final tab = _workspace.activeTab;
    if (placement == PanePlacement.newTab || tab == null || tab.isEmpty) {
      final fresh = WorkspaceTab(
        id: Ids.next(),
        root: LeafNode(pane.id),
        panes: {pane.id: pane},
        focusedPaneId: pane.id,
      );
      _updateWorkspace(
        (workspace) => workspace.copyWith(
          tabs: [...workspace.tabs.where((item) => !item.isEmpty), fresh],
          activeTabId: () => fresh.id,
        ),
      );
      return pane.id;
    }
    if (placement == PanePlacement.replaceFocused &&
        tab.focusedPaneId != null) {
      final old = tab.focusedPaneId!;
      _updateTab(
        tab.id,
        (tab) => tab.copyWith(
          root: () => Layouts.swap(tab.root, old, pane.id) ?? LeafNode(pane.id),
          panes: ({...tab.panes}..remove(old))..[pane.id] = pane,
          focusedPaneId: () => pane.id,
        ),
      );
      return pane.id;
    }
    final axis = placement == PanePlacement.splitDown
        ? SplitAxis.vertical
        : SplitAxis.horizontal;
    _updateTab(
      tab.id,
      (tab) => tab.copyWith(
        root: () => Layouts.split(
          tab.root,
          tab.focusedPaneId,
          pane.id,
          axis,
          splitId: Ids.next(),
        ),
        panes: {...tab.panes, pane.id: pane},
        focusedPaneId: () => pane.id,
        maximizedPaneId: () => null,
      ),
    );
    return pane.id;
  }

  String openTabWith(
    List<PaneContent> contents, {
    LayoutPresetKind preset = LayoutPresetKind.grid,
    String? title,
  }) {
    final panes = [
      for (final content in contents)
        Pane(id: Ids.next(), content: _prepare(content)),
    ];
    final tab = WorkspaceTab(
      id: Ids.next(),
      title: title,
      root: Layouts.preset(preset, [
        for (final pane in panes) pane.id,
      ], Ids.next),
      panes: {for (final pane in panes) pane.id: pane},
      focusedPaneId: panes.firstOrNull?.id,
    );
    _updateWorkspace(
      (workspace) => workspace.copyWith(
        tabs: [...workspace.tabs, tab],
        activeTabId: () => tab.id,
      ),
    );
    return tab.id;
  }

  void selectTab(String tabId) => _updateWorkspace(
    (workspace) => workspace.copyWith(activeTabId: () => tabId),
  );

  void selectTabAt(int index) {
    final tabs = _workspace.tabs;
    if (index >= 0 && index < tabs.length) selectTab(tabs[index].id);
  }

  void cycleTab(int delta) {
    final tabs = _workspace.tabs;
    if (tabs.isEmpty) return;
    final current = tabs.indexWhere(
      (tab) => tab.id == _workspace.activeTab?.id,
    );
    selectTab(tabs[(current + delta) % tabs.length].id);
  }

  void renameTab(String tabId, String? title) => _updateTab(
    tabId,
    (tab) => tab.copyWith(
      title: () => title?.trim().isEmpty ?? true ? null : title!.trim(),
    ),
  );

  void closeTab(String tabId) {
    for (final workspace in state.workspaces) {
      final index = workspace.tabs.indexWhere((tab) => tab.id == tabId);
      if (index < 0) continue;
      final tab = workspace.tabs[index];
      final tabs = [...workspace.tabs]..removeAt(index);
      final nextActive = workspace.activeTabId == tabId
          ? (tabs.isEmpty
                ? null
                : tabs[(index - 1).clamp(0, tabs.length - 1)].id)
          : workspace.activeTabId;
      state = state
          .replaceWorkspace(
            workspace.copyWith(tabs: tabs, activeTabId: () => nextActive),
          )
          .copyWith(
            broadcastPaneIds: state.broadcastPaneIds.difference(
              tab.panes.keys.toSet(),
            ),
          );
      return;
    }
  }

  void moveTab(String tabId, int toIndex) => _updateWorkspace((workspace) {
    final tabs = [...workspace.tabs];
    final from = tabs.indexWhere((tab) => tab.id == tabId);
    if (from < 0) return workspace;
    final tab = tabs.removeAt(from);
    tabs.insert(toIndex.clamp(0, tabs.length), tab);
    return workspace.copyWith(tabs: tabs);
  });

  void closePane(String paneId) {
    final location = state.locate(paneId);
    if (location == null) return;
    final tab = location.tab;
    final root = Layouts.remove(tab.root, paneId);
    if (root == null) {
      closeTab(tab.id);
      return;
    }
    final order = Layouts.leaves(root);
    _updateTab(
      tab.id,
      (tab) => tab.copyWith(
        root: () => root,
        panes: {...tab.panes}..remove(paneId),
        focusedPaneId: () =>
            tab.focusedPaneId == paneId ? order.first : tab.focusedPaneId,
        maximizedPaneId: () =>
            tab.maximizedPaneId == paneId ? null : tab.maximizedPaneId,
      ),
    );
    state = state.copyWith(
      broadcastPaneIds: {...state.broadcastPaneIds}..remove(paneId),
    );
  }

  void closeFocusedPane() {
    final id = state.activeTab?.focusedPaneId;
    if (id != null) closePane(id);
  }

  void focusPane(String paneId) {
    final location = state.locate(paneId);
    if (location == null || location.tab.focusedPaneId == paneId) return;
    _updateTab(
      location.tab.id,
      (tab) => tab.copyWith(focusedPaneId: () => paneId),
    );
  }

  void focusDirection(PaneDirection direction) {
    final tab = state.activeTab;
    final focused = tab?.focusedPaneId;
    if (tab == null || focused == null || tab.maximizedPaneId != null) return;
    final next = Layouts.neighbor(tab.root, focused, direction);
    if (next != null) focusPane(next);
  }

  void resizeFocused(PaneDirection direction) {
    final tab = state.activeTab;
    final focused = tab?.focusedPaneId;
    if (tab == null || focused == null) return;
    _updateTab(
      tab.id,
      (tab) => tab.copyWith(
        root: () => Layouts.resize(tab.root, focused, direction, resizeStep),
      ),
    );
  }

  void setRatio(String tabId, String splitId, double ratio) => _updateTab(
    tabId,
    (tab) =>
        tab.copyWith(root: () => Layouts.setRatio(tab.root, splitId, ratio)),
  );

  void toggleMaximize([String? paneId]) {
    final tab = state.activeTab;
    final id = paneId ?? tab?.focusedPaneId;
    if (tab == null || id == null) return;
    _updateTab(
      tab.id,
      (tab) => tab.copyWith(
        maximizedPaneId: () => tab.maximizedPaneId == id ? null : id,
        focusedPaneId: () => id,
      ),
    );
  }

  void swapPanes(String a, String b) {
    final location = state.locate(a);
    if (location == null || !location.tab.panes.containsKey(b)) return;
    _updateTab(
      location.tab.id,
      (tab) => tab.copyWith(root: () => Layouts.swap(tab.root, a, b)),
    );
  }

  void swapWithNeighbor(PaneDirection direction) {
    final tab = state.activeTab;
    final focused = tab?.focusedPaneId;
    if (tab == null || focused == null) return;
    final other = Layouts.neighbor(tab.root, focused, direction);
    if (other != null) swapPanes(focused, other);
  }

  void movePaneToTab(String paneId, {String? tabId}) {
    final location = state.locate(paneId);
    if (location == null || location.tab.id == tabId) return;
    final pane = location.pane;
    final root = Layouts.remove(location.tab.root, paneId);
    if (root == null) {
      state = state.replaceWorkspace(
        location.workspace.copyWith(
          tabs: location.workspace.tabs
              .where((tab) => tab.id != location.tab.id)
              .toList(),
        ),
      );
    } else {
      _updateTab(
        location.tab.id,
        (tab) => tab.copyWith(
          root: () => root,
          panes: {...tab.panes}..remove(paneId),
          focusedPaneId: () => Layouts.leaves(root).first,
          maximizedPaneId: () => null,
        ),
      );
    }
    final target = tabId == null
        ? null
        : state.workspaces
              .expand((w) => w.tabs)
              .firstWhereOrNull((t) => t.id == tabId);
    if (target == null) {
      final fresh = WorkspaceTab(
        id: Ids.next(),
        root: LeafNode(pane.id),
        panes: {pane.id: pane},
        focusedPaneId: pane.id,
      );
      _updateWorkspace(
        (workspace) => workspace.copyWith(
          tabs: [...workspace.tabs, fresh],
          activeTabId: () => fresh.id,
        ),
      );
      return;
    }
    _updateTab(
      target.id,
      (tab) => tab.copyWith(
        root: () => Layouts.split(
          tab.root,
          tab.focusedPaneId,
          pane.id,
          SplitAxis.horizontal,
          splitId: Ids.next(),
        ),
        panes: {...tab.panes, pane.id: pane},
        focusedPaneId: () => pane.id,
      ),
    );
    reveal(pane.id);
  }

  void movePaneToWorkspace(String paneId, String workspaceId) {
    final target = state.workspaces.firstWhereOrNull(
      (w) => w.id == workspaceId,
    );
    if (target == null) return;
    final location = state.locate(paneId);
    if (location == null || location.workspace.id == workspaceId) return;
    final targetTab = target.activeTab;
    switchWorkspace(workspaceId);
    if (targetTab == null) {
      movePaneToTab(paneId);
    } else {
      movePaneToTab(paneId, tabId: targetTab.id);
    }
  }

  void applyPreset(LayoutPresetKind kind) {
    final tab = state.activeTab;
    if (tab == null || tab.isEmpty) return;
    _updateTab(
      tab.id,
      (tab) => tab.copyWith(
        root: () => Layouts.preset(kind, tab.paneOrder, Ids.next),
        maximizedPaneId: () => null,
      ),
    );
  }

  void updatePane(String paneId, PaneContent content) {
    final location = state.locate(paneId);
    if (location == null) return;
    _updateTab(
      location.tab.id,
      (tab) => tab.copyWith(
        panes: {...tab.panes, paneId: location.pane.withContent(content)},
      ),
    );
  }

  void toggleBroadcast(String paneId) {
    final next = {...state.broadcastPaneIds};
    if (!next.remove(paneId)) next.add(paneId);
    state = state.copyWith(broadcastPaneIds: next);
  }

  void setBroadcast(Set<String> paneIds) =>
      state = state.copyWith(broadcastPaneIds: paneIds);

  void toggleBroadcastForTab() {
    final tab = state.activeTab;
    if (tab == null) return;
    final terminals = tab.panes.values
        .where(
          (pane) =>
              pane.content is SshTerminalContent ||
              pane.content is LocalTerminalContent,
        )
        .map((pane) => pane.id)
        .toSet();
    final allOn =
        terminals.isNotEmpty &&
        terminals.every(state.broadcastPaneIds.contains);
    setBroadcast(
      allOn
          ? state.broadcastPaneIds.difference(terminals)
          : {...state.broadcastPaneIds, ...terminals},
    );
  }

  Future<List<SavedLayout>> savedLayouts() async {
    final docs = await ref
        .read(documentStoreProvider)
        .all(layoutsCollection, newestFirst: true);
    return [for (final json in docs) SavedLayout.fromJson(json)];
  }

  Future<void> saveActiveTabAs(String name) async {
    final tab = state.activeTab;
    if (tab == null || tab.isEmpty) return;
    final layout = SavedLayout(
      id: Ids.next(),
      name: name.trim(),
      tab: tab,
      savedAt: DateTime.now(),
    );
    await ref
        .read(documentStoreProvider)
        .put(layoutsCollection, layout.id, layout.toJson());
  }

  Future<void> deleteSavedLayout(String id) =>
      ref.read(documentStoreProvider).delete(layoutsCollection, id);

  void openSavedLayout(SavedLayout layout) {
    final idMap = <String, String>{};
    String mapPane(String old) => idMap.putIfAbsent(old, Ids.next);
    final root = layout.tab.root == null
        ? null
        : Layouts.remap(layout.tab.root!, mapPane, Ids.next);
    final panes = {
      for (final MapEntry(key: old, value: pane) in layout.tab.panes.entries)
        mapPane(old): Pane(
          id: mapPane(old),
          content: pane.content,
          origin: pane.origin,
        ),
    };
    final tab = WorkspaceTab(
      id: Ids.next(),
      title: layout.name,
      root: root,
      panes: panes,
      focusedPaneId: root == null ? null : Layouts.leaves(root).first,
    );
    _updateWorkspace(
      (workspace) => workspace.copyWith(
        tabs: [...workspace.tabs, tab],
        activeTabId: () => tab.id,
      ),
    );
  }
}
