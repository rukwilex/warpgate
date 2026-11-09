import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class PortForwardRow extends StatelessWidget {
  const new({required this.forward, required this.onRemove, super.key});

  final PortForwardSpec forward;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => WgListRow(
    title: forward.summary,
    meta: [
      forward.kind.label,
      if (forward.autoStart) 'starts on connect',
    ].join(' · '),
    leading: const Icon(WgIcons.forward),
    trailing: WgIconButton(
      icon: WgIcons.trash,
      label: 'Remove forward',
      compact: true,
      onPressed: onRemove,
    ),
  );
}
