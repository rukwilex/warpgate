import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/widgets/host_field_label.dart';

class PortForwardsHeader extends StatelessWidget {
  const new({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: HostFieldLabel('Port forwards')),
      WgButton.ghost(
        label: 'Add forward',
        icon: WgIcons.plus,
        onPressed: onAdd,
      ),
    ],
  );
}
