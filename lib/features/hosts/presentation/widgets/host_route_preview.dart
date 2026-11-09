import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/utils/host_route.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class HostRoutePreview extends StatelessWidget {
  const new({
    required this.label,
    required this.jumpHostId,
    required this.byId,
    super.key,
  });

  final String label;
  final String jumpHostId;
  final Map<String, Host> byId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: context.space.xs),
    child: Text(
      'Route: ${hostRoute(label: label, jumpHostId: jumpHostId, byId: byId)}',
      style: context.type.monoSmall.copyWith(
        color: context.colors.textMuted,
      ),
    ),
  );
}
