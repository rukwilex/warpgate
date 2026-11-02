import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';
import 'package:warpgate/features/workspace/domain/pane.dart';

@immutable
class WorkspaceTab {
  const new({
    required this.id,
    this.title,
    this.root,
    this.panes = const {},
    this.focusedPaneId,
    this.maximizedPaneId,
  });

  factory fromJson(JsonMap json) {
    final panes = {
      for (final item in (json['panes'] as List?) ?? const <Object?>[])
        Pane.fromJson((item! as Map).cast()),
    };
    return WorkspaceTab(
      id: json['id']! as String,
      title: json['title'] as String?,
      root: json['root'] == null
          ? null
          : LayoutNode.fromJson((json['root']! as Map).cast()),
      panes: {for (final pane in panes) pane.id: pane},
      focusedPaneId: json['focusedPaneId'] as String?,
      maximizedPaneId: json['maximizedPaneId'] as String?,
    );
  }

  final String id;
  final String? title;
  final LayoutNode? root;
  final Map<String, Pane> panes;
  final String? focusedPaneId;
  final String? maximizedPaneId;

  List<String> get paneOrder => Layouts.leaves(root);

  Pane? get focusedPane => focusedPaneId == null ? null : panes[focusedPaneId];

  bool get isEmpty => root == null;

  WorkspaceTab copyWith({
    String? Function()? title,
    LayoutNode? Function()? root,
    Map<String, Pane>? panes,
    String? Function()? focusedPaneId,
    String? Function()? maximizedPaneId,
  }) => WorkspaceTab(
    id: id,
    title: title == null ? this.title : title(),
    root: root == null ? this.root : root(),
    panes: panes ?? this.panes,
    focusedPaneId: focusedPaneId == null ? this.focusedPaneId : focusedPaneId(),
    maximizedPaneId: maximizedPaneId == null
        ? this.maximizedPaneId
        : maximizedPaneId(),
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'root': root?.toJson(),
    'panes': [for (final id in paneOrder) panes[id]!.toJson()],
    'focusedPaneId': focusedPaneId,
    'maximizedPaneId': maximizedPaneId,
  };
}

@immutable
class Workspace {
  const new({
    required this.id,
    required this.name,
    this.tabs = const [],
    this.activeTabId,
  });

  factory fromJson(JsonMap json) => Workspace(
    id: json['id']! as String,
    name: json['name']! as String,
    tabs: [
      for (final item in (json['tabs'] as List?) ?? const <Object?>[])
        WorkspaceTab.fromJson((item! as Map).cast()),
    ],
    activeTabId: json['activeTabId'] as String?,
  );

  final String id;
  final String name;
  final List<WorkspaceTab> tabs;
  final String? activeTabId;

  WorkspaceTab? get activeTab =>
      tabs.firstWhereOrNull((tab) => tab.id == activeTabId) ?? tabs.firstOrNull;

  Iterable<Pane> get panes => tabs.expand((tab) => tab.panes.values);

  Workspace copyWith({
    String? name,
    List<WorkspaceTab>? tabs,
    String? Function()? activeTabId,
  }) => Workspace(
    id: id,
    name: name ?? this.name,
    tabs: tabs ?? this.tabs,
    activeTabId: activeTabId == null ? this.activeTabId : activeTabId(),
  );

  Workspace replaceTab(WorkspaceTab tab) => copyWith(
    tabs: [
      for (final item in tabs)
        if (item.id == tab.id) tab else item,
    ],
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'tabs': [for (final tab in tabs) tab.toJson()],
    'activeTabId': activeTabId,
  };
}

@immutable
class SavedLayout {
  const new({
    required this.id,
    required this.name,
    required this.tab,
    required this.savedAt,
  });

  factory fromJson(JsonMap json) => SavedLayout(
    id: json['id']! as String,
    name: json['name']! as String,
    tab: WorkspaceTab.fromJson((json['tab']! as Map).cast()),
    savedAt: DateTime.parse(json['savedAt']! as String),
  );

  final String id;
  final String name;
  final WorkspaceTab tab;
  final DateTime savedAt;

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'tab': tab.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };
}

@immutable
class PaneLocation {
  const new({required this.workspace, required this.tab, required this.pane});

  final Workspace workspace;
  final WorkspaceTab tab;
  final Pane pane;
}

@immutable
class WorkbenchState {
  const new({
    this.workspaces = const [],
    this.activeWorkspaceId,
    this.broadcastPaneIds = const {},
  });

  factory fromJson(JsonMap json) => WorkbenchState(
    workspaces: [
      for (final item in (json['workspaces'] as List?) ?? const <Object?>[])
        Workspace.fromJson((item! as Map).cast()),
    ],
    activeWorkspaceId: json['activeWorkspaceId'] as String?,
  );

  final List<Workspace> workspaces;
  final String? activeWorkspaceId;
  final Set<String> broadcastPaneIds;

  Workspace? get activeWorkspace =>
      workspaces.firstWhereOrNull((item) => item.id == activeWorkspaceId) ??
      workspaces.firstOrNull;

  WorkspaceTab? get activeTab => activeWorkspace?.activeTab;

  Pane? get focusedPane => activeTab?.focusedPane;

  Iterable<PaneLocation> get allPanes sync* {
    for (final workspace in workspaces) {
      for (final tab in workspace.tabs) {
        for (final id in tab.paneOrder) {
          yield PaneLocation(
            workspace: workspace,
            tab: tab,
            pane: tab.panes[id]!,
          );
        }
      }
    }
  }

  PaneLocation? locate(String paneId) =>
      allPanes.firstWhereOrNull((location) => location.pane.id == paneId);

  WorkbenchState copyWith({
    List<Workspace>? workspaces,
    String? Function()? activeWorkspaceId,
    Set<String>? broadcastPaneIds,
  }) => WorkbenchState(
    workspaces: workspaces ?? this.workspaces,
    activeWorkspaceId: activeWorkspaceId == null
        ? this.activeWorkspaceId
        : activeWorkspaceId(),
    broadcastPaneIds: broadcastPaneIds ?? this.broadcastPaneIds,
  );

  WorkbenchState replaceWorkspace(Workspace workspace) => copyWith(
    workspaces: [
      for (final item in workspaces)
        if (item.id == workspace.id) workspace else item,
    ],
  );

  JsonMap toJson() => {
    'workspaces': [for (final workspace in workspaces) workspace.toJson()],
    'activeWorkspaceId': activeWorkspaceId,
  };
}
