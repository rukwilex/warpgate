import 'package:flutter/widgets.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class Routes {
  static const workbench = '/';
  static const hosts = '/hosts';
  static const keys = '/keys';
  static const transfers = '/transfers';
  static const multiExec = '/multi-exec';
  static const snippets = '/snippets';
  static const forwards = '/forwards';
  static const settings = '/settings';
  static const mcpActivity = '/settings/mcp-activity';
}
