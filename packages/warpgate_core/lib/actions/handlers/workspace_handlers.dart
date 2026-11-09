import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/workspace/domain/layout.dart';

abstract final class WorkspaceHandlers {
  static final Map<String, ActionHandler> all = {
    'workspaces.list': _workspacesList,
    'layouts.list': _layoutsList,
  };

  static Future<JsonMap> _workspacesList(ActionCall call) async {
    final json = await call.runtime.store.get(StoreKeys.workbench, StoreKeys.workbenchState);
    final active = json?['activeWorkspaceId'];
    return {
      'workspaces': [
        for (final item in (json?['workspaces'] as List?) ?? const <Object?>[])
          if (item is Map)
            {
              'id': item['id'],
              'name': item['name'],
              'active': item['id'] == active,
              'tabs': (item['tabs'] as List?)?.length ?? 0,
            },
      ],
    };
  }

  static Future<JsonMap> _layoutsList(ActionCall call) async => {
    'layouts': [
      for (final json in await call.runtime.store.all(StoreKeys.savedLayouts, newestFirst: true))
        {'id': json['id'], 'name': json['name'], 'saved_at': json['savedAt']},
    ],
    'presets': [for (final preset in LayoutPresetKind.values) preset.name],
  };
}
