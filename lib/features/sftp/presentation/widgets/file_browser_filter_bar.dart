import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';

class FileBrowserFilterBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.onChanged,
    required this.onClose,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.space.xs),
      decoration: BoxDecoration(
        color: context.colors.canvasDeep,
        border: Border(bottom: BorderSide(color: context.colors.hairline)),
      ),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
        child: WgTextField(
          controller: controller,
          autofocus: true,
          placeholder: 'Filter this folder',
          leadingIcon: WgIcons.search,
          onChanged: onChanged,
          trailing: WgIconButton(
            icon: WgIcons.close,
            label: 'Clear filter',
            compact: true,
            onPressed: onClose,
          ),
        ),
      ),
    );
  }
}
