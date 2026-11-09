import 'package:warpgate_core/actions/handlers/backup_handlers.dart';
import 'package:warpgate_core/actions/handlers/files_handlers.dart';
import 'package:warpgate_core/actions/handlers/forwards_handlers.dart';
import 'package:warpgate_core/actions/handlers/hosts_handlers.dart';
import 'package:warpgate_core/actions/handlers/keys_handlers.dart';
import 'package:warpgate_core/actions/handlers/known_hosts_handlers.dart';
import 'package:warpgate_core/actions/handlers/mcp_handlers.dart';
import 'package:warpgate_core/actions/handlers/settings_handlers.dart';
import 'package:warpgate_core/actions/handlers/snippets_handlers.dart';
import 'package:warpgate_core/actions/handlers/transfers_handlers.dart';
import 'package:warpgate_core/actions/handlers/workspace_handlers.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/lookups.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

export 'package:warpgate_core/actions/support/action_call.dart';
export 'package:warpgate_core/actions/support/forward_specs.dart';
export 'package:warpgate_core/actions/support/globs.dart';
export 'package:warpgate_core/actions/support/json_views.dart';

abstract final class ActionHandlers {
  static final Map<String, ActionHandler> all = {
    ...HostHandlers.all,
    ...KeyHandlers.all,
    ...KnownHostHandlers.all,
    ...FileHandlers.all,
    ...TransferHandlers.all,
    ...ForwardHandlers.all,
    ...SnippetHandlers.all,
    ...WorkspaceHandlers.all,
    ...SettingsHandlers.all,
    ...BackupHandlers.all,
    ...McpHandlers.all,
  };

  static Future<TransferJob> findJob(WarpgateRuntime rt, String reference) =>
      Lookups.findJob(rt, reference);

  static Future<Snippet> findSnippet(WarpgateRuntime rt, String reference) =>
      Lookups.findSnippet(rt, reference);

  static String newToken() => McpHandlers.newToken();
}
