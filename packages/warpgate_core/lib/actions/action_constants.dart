abstract final class ActionHelp {
  static const host = 'Host label, id or user@host[:port]';
  static const session = 'Session id. Run warpgate sessions list to see them';
}

abstract final class ActionLimits {
  static const int maxReadBytes = 64 * 1024 * 1024;
  static const findMatches = 1000;
  static const maxPort = 65535;
  static const maxMode = 4095;
  static const rsaBits = 4096;
  static const tokenBytes = 32;
  static const mcpActivityKept = 500;
}

abstract final class ActionTimeouts {
  static const hostKeyConnect = Duration(seconds: 12);
  static const hostKeyHandshake = Duration(seconds: 15);
  static const transferPoll = Duration(milliseconds: 500);
  static const progressTick = Duration(milliseconds: 200);
}

abstract final class ActionDefaults {
  static const bindHost = '127.0.0.1';
}

abstract final class ActionOrigins {
  static const cli = 'cli';
  static const claudeCode = 'claude_code';
}

abstract final class StoreKeys {
  static const workbench = 'workbench';
  static const workbenchState = 'state';
  static const savedLayouts = 'saved_layouts';
  static const mcpActivity = 'mcp_activity';
}
