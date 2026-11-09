import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';

class TerminalFilesToggle extends StatelessWidget {
  const new({
    required this.open,
    required this.onPressed,
    this.shortcut,
    super.key,
  });

  final bool open;
  final VoidCallback onPressed;
  final SingleActivator? shortcut;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      WgIconButton(
        icon: WgIcons.filesPanel,
        label: open ? 'Hide files' : 'Show files',
        compact: true,
        selected: open,
        shortcut: shortcut,
        onPressed: onPressed,
      ),
    ],
  );
}
