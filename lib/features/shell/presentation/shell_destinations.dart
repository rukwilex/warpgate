import 'package:flutter/widgets.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';

@immutable
class ShellDestination {
  const new(this.route, this.label, this.icon, {this.commandId});

  final String route;
  final String label;
  final IconData icon;
  final String? commandId;
}

const shellDestinations = [
  ShellDestination(
    Routes.workbench,
    'Sessions',
    WgIcons.terminal,
    commandId: 'nav.workbench',
  ),
  ShellDestination(Routes.hosts, 'Hosts', WgIcons.server, commandId: 'nav.hosts'),
  ShellDestination(
    Routes.transfers,
    'Transfers',
    WgIcons.transfer,
    commandId: 'transfers.open',
  ),
  ShellDestination(
    Routes.multiExec,
    'Run on many',
    WgIcons.multiExec,
    commandId: 'multiExec.open',
  ),
  ShellDestination(
    Routes.snippets,
    'Snippets',
    WgIcons.snippet,
    commandId: 'nav.snippets',
  ),
  ShellDestination(Routes.keys, 'Keys', WgIcons.key, commandId: 'nav.keys'),
  ShellDestination(
    Routes.forwards,
    'Port forwards',
    WgIcons.forward,
    commandId: 'nav.forwards',
  ),
  ShellDestination(
    Routes.settings,
    'Settings',
    WgIcons.settings,
    commandId: 'settings.open',
  ),
];

const shellPhoneDestinations = [
  ShellDestination(Routes.workbench, 'Sessions', WgIcons.terminal),
  ShellDestination(Routes.hosts, 'Hosts', WgIcons.server),
  ShellDestination(Routes.transfers, 'Transfers', WgIcons.transfer),
  ShellDestination(Routes.multiExec, 'Many', WgIcons.multiExec),
  ShellDestination(Routes.settings, 'Settings', WgIcons.settings),
];
