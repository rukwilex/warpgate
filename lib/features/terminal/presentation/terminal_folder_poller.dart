import 'dart:async';

import 'package:warpgate/features/terminal/data/terminal_session.dart';

class TerminalFolderPoller {
  Timer? _timer;

  void sync(
    TerminalSession session, {
    required bool wanted,
    required Duration interval,
  }) {
    if (wanted && _timer == null) {
      unawaited(session.pollFolder());
      _timer = Timer.periodic(
        interval,
        (_) => unawaited(session.pollFolder()),
      );
    } else if (!wanted && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() => _timer?.cancel();
}
