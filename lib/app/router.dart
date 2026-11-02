import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/connection/presentation/forwards_screen.dart';
import 'package:warpgate/features/hosts/presentation/hosts_screen.dart';
import 'package:warpgate/features/keys/presentation/keys_screen.dart';
import 'package:warpgate/features/mcp/presentation/mcp_activity_screen.dart';
import 'package:warpgate/features/multi_exec/presentation/multi_exec_screen.dart';
import 'package:warpgate/features/settings/presentation/settings_screen.dart';
import 'package:warpgate/features/shell/presentation/app_shell.dart';
import 'package:warpgate/features/snippets/presentation/snippets_screen.dart';
import 'package:warpgate/features/transfers/presentation/transfers_screen.dart';
import 'package:warpgate/features/workspace/presentation/workbench_screen.dart';

GoRouter buildRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: Routes.workbench,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: Routes.workbench,
          pageBuilder: (context, state) => NoTransitionPage(
            child: Builder(
              builder: (context) => WorkbenchScreen(
                phone: shellLayoutOf(context) == ShellLayout.phone,
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.hosts,
          pageBuilder: (context, state) =>
              NoTransitionPage(child: HostsScreen(intent: state.extra)),
        ),
        GoRoute(
          path: Routes.keys,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: KeysScreen()),
        ),
        GoRoute(
          path: Routes.transfers,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TransfersScreen()),
        ),
        GoRoute(
          path: Routes.multiExec,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MultiExecScreen()),
        ),
        GoRoute(
          path: Routes.snippets,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SnippetsScreen()),
        ),
        GoRoute(
          path: Routes.forwards,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ForwardsScreen()),
        ),
        GoRoute(
          path: Routes.settings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: Routes.mcpActivity,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: McpActivityScreen()),
        ),
      ],
    ),
  ],
);
