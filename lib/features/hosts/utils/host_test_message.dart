import 'package:warpgate/features/hosts/presentation/hosts_constants.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';

String hostTestMessage(ExecResult result, {required bool tmuxWanted}) {
  if (result.succeeded) {
    final lines = result.stdout.trim().split('\n');
    final tmux = lines.contains(HostsConstants.testTmuxOk);
    return 'Connected. ${lines.first}${tmuxWanted && !tmux ? '. tmux is not installed, so sessions will not survive a disconnect' : ''}';
  }
  return result.error ??
      (result.stderr.trim().isEmpty
          ? 'The test command failed'
          : result.stderr.trim());
}
