import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class WebUnsupportedScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.canvas,
    body: const WgEmptyState(
      icon: WgIcons.terminal,
      title: 'Warpgate does not run in a browser',
      body:
          'Browsers cannot open raw TCP connections, so SSH and SFTP need the desktop or mobile app. '
          'Install Warpgate for macOS, Windows, Linux, iOS or Android.',
    ),
  );
}
