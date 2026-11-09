import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/presentation/widgets/terminal_paste_preview.dart';

Future<bool> confirmFolderTracking(
  BuildContext context, {
  required String host,
}) => showWgConfirm(
  context,
  title: 'Track the folder of this shell?',
  message:
      'Warpgate adds one line to your shell startup file on $host (.bashrc, .zshrc or fish conf.d). The line tells the app which folder the shell is in after every command, so the files panel can follow it. It also runs in this terminal now.',
  confirmLabel: 'Turn on folder tracking',
);

Future<bool> confirmMultilinePaste(
  BuildContext context, {
  required String text,
  required int lines,
}) => showWgConfirm(
  context,
  title: 'Paste $lines lines?',
  message: 'Each line may run as a separate command as soon as it arrives.',
  confirmLabel: 'Paste $lines lines',
  detail: TerminalPastePreview(text: text),
);
