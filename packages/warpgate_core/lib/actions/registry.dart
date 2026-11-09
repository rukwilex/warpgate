import 'package:warpgate_core/actions/action_spec.dart';
import 'package:warpgate_core/actions/registry/connect_actions.dart';
import 'package:warpgate_core/actions/registry/files_actions.dart';
import 'package:warpgate_core/actions/registry/forwards_actions.dart';
import 'package:warpgate_core/actions/registry/hosts_actions.dart';
import 'package:warpgate_core/actions/registry/keys_actions.dart';
import 'package:warpgate_core/actions/registry/known_hosts_actions.dart';
import 'package:warpgate_core/actions/registry/mcp_actions.dart';
import 'package:warpgate_core/actions/registry/navigation_actions.dart';
import 'package:warpgate_core/actions/registry/panes_actions.dart';
import 'package:warpgate_core/actions/registry/sessions_actions.dart';
import 'package:warpgate_core/actions/registry/settings_actions.dart';
import 'package:warpgate_core/actions/registry/snippets_actions.dart';
import 'package:warpgate_core/actions/registry/system_actions.dart';
import 'package:warpgate_core/actions/registry/transfers_actions.dart';
import 'package:warpgate_core/actions/registry/workspace_actions.dart';

export 'package:warpgate_core/actions/action_spec.dart';
export 'package:warpgate_core/actions/registry/shapes.dart';
export 'package:warpgate_core/actions/registry/tables.dart';

abstract final class ActionRegistry {
  static final List<ActionSpec> all = [
    ...ConnectActionSpecs.all,
    ...HostActionSpecs.all,
    ...KeyActionSpecs.all,
    ...KnownHostActionSpecs.all,
    ...FileActionSpecs.all,
    ...TransferActionSpecs.all,
    ...ForwardActionSpecs.all,
    ...SnippetActionSpecs.all,
    ...SessionActionSpecs.all,
    ...WorkspaceActionSpecs.all,
    ...PaneActionSpecs.all,
    ...NavigationActionSpecs.all,
    ...SettingsActionSpecs.all,
    ...McpActionSpecs.all,
    ...SystemActionSpecs.all,
  ];

  static final Map<String, ActionSpec> byName = {
    for (final action in all) action.name: action,
  };

  static Iterable<PaletteEntry> get paletteEntries =>
      all.expand((action) => action.palette);

  static ActionSpec? forPalette(String id) {
    for (final action in all) {
      if (action.palette.any((entry) => entry.id == id)) return action;
    }
    return null;
  }
}
