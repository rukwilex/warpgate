import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class HostMcpAccessHint extends StatelessWidget {
  const new({required this.permission, super.key});

  final McpPermission permission;

  @override
  Widget build(BuildContext context) => Text(switch (permission) {
    McpPermission.off => 'Claude Code cannot see this host.',
    McpPermission.readOnly => 'Claude Code can list files, read files and read terminals. It cannot run commands or change anything.',
    McpPermission.full => 'Claude Code can run commands, type into terminals and change files. Passwords and keys are never shared.',
  }, style: context.type.caption);
}
