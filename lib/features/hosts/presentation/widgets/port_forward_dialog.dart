import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_constants.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class PortForwardDialog extends StatefulWidget {
  const new({super.key});

  @override
  State<PortForwardDialog> createState() => _PortForwardDialogState();
}

class _PortForwardDialogState extends State<PortForwardDialog> {
  ForwardKind _kind = ForwardKind.local;
  final _bind = TextEditingController(text: '${HostsConstants.forwardBindPort}');
  final _host = TextEditingController(text: HostsConstants.forwardTargetHost);
  final _target = TextEditingController(
    text: '${HostsConstants.forwardTargetPort}',
  );
  bool _auto = false;

  @override
  void dispose() {
    _bind.dispose();
    _host.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: context.space.lg);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return WgDialog(
      title: 'Add port forward',
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        WgButton.primary(
          label: 'Add',
          onPressed: () {
            final bind = int.tryParse(_bind.text);
            final target = int.tryParse(_target.text) ?? 0;
            if (bind == null) return;
            Navigator.of(context).pop(
              PortForwardSpec(
                id: Ids.short(),
                kind: _kind,
                bindPort: bind,
                targetHost: _host.text.trim(),
                targetPort: target,
                autoStart: _auto,
              ),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WgSegmented<ForwardKind>(
            label: 'Forward type',
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
            segments: [
              for (final kind in ForwardKind.values)
                WgSegment(kind, kind.label),
            ],
          ),
          SizedBox(height: context.space.sm),
          Text(switch (_kind) {
            ForwardKind.local => 'A port on this device reaches a host and port seen from the server.',
            ForwardKind.remote => 'A port on the server reaches a host and port seen from this device.',
            ForwardKind.dynamic => 'A SOCKS proxy on this device sends traffic out through the server.',
          }, style: context.type.caption),
          gap,
          WgTextField(
            controller: _bind,
            label: _kind == ForwardKind.remote
                ? 'Port on the server'
                : 'Port on this device',
            mono: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
          ),
          if (_kind != ForwardKind.dynamic) ...[
            gap,
            WgTextField(controller: _host, label: 'Target host', mono: true),
            gap,
            WgTextField(
              controller: _target,
              label: 'Target port',
              mono: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
            ),
          ],
          gap,
          WgCheckRow(
            label: 'Start when the host connects',
            value: _auto,
            onChanged: (value) => setState(() => _auto = value),
          ),
        ],
      ),
    );
  }
}
