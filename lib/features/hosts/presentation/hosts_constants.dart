abstract final class HostsConstants {
  static const defaultPort = 22;
  static const minPort = 1;
  static const maxPort = 65535;
  static const defaultKeepAliveSeconds = 15;
  static const maxKeepAliveSeconds = 3600;
  static const testCommand =
      'uname -sr; command -v tmux >/dev/null && echo tmux-ok || echo tmux-missing';
  static const testTmuxOk = 'tmux-ok';
  static const forwardBindPort = 8080;
  static const forwardTargetHost = 'localhost';
  static const forwardTargetPort = 80;
}
