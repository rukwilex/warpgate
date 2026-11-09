import 'package:flutter/widgets.dart';
import 'package:warpgate/features/sftp/presentation/sftp_pane.dart';
import 'package:warpgate/features/terminal/presentation/log_tail_pane.dart';
import 'package:warpgate/features/terminal/presentation/terminal_pane.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

Widget buildPane(Pane pane, {bool compactChrome = false}) =>
    switch (pane.content) {
      SshTerminalContent() || LocalTerminalContent() => TerminalPane(
        pane: pane,
        compactChrome: compactChrome,
      ),
      SftpContent() => SftpPane(pane: pane, compactChrome: compactChrome),
      LogTailContent() => LogTailPane(pane: pane, compactChrome: compactChrome),
    };
