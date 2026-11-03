import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/connection/data/port_forwarder.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/host_editor.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';

class ForwardsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(hostsProvider).value ?? const HostsCatalog();
    final active = ref.watch(activeForwardsProvider);
    final forwarder = ref.read(portForwarderProvider);
    final hosts = catalog.hosts
        .where((host) => host.forwards.isNotEmpty)
        .toList();
    final colors = context.colors;
    return WgPage(
      title: 'Port forwards',
      subtitle: 'Forwards are set per host. Start them here or have them start when the host connects',
      empty: hosts.isEmpty
          ? const WgEmptyState(
              icon: WgIcons.forward,
              title: 'No port forwards',
              body: 'Open a host in Hosts, choose Edit, and add a local, remote or SOCKS forward.',
            )
          : null,
      child: hosts.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final host in hosts) ...[
                  WgSectionLabel(
                    host.label,
                    trailing: WgIconButton(
                      icon: WgIcons.edit,
                      label: 'Edit forwards of ${host.label}',
                      compact: true,
                      onPressed: () =>
                          unawaited(showHostEditor(context, host: host)),
                    ),
                  ),
                  for (final spec in host.forwards)
                    Builder(
                      builder: (context) {
                        final state = active.find(host.id, spec.id);
                        final running = state?.state == ForwardState.active;
                        final dot = switch (state?.state) {
                          ForwardState.active =>
                            (state!.connections > 0
                                ? WgDotState.busy
                                : WgDotState.connected),
                          ForwardState.starting => WgDotState.connecting,
                          ForwardState.failed => WgDotState.dropped,
                          ForwardState.stopped || null => WgDotState.idle,
                        };
                        return WgListRow(
                          title: spec.summary,
                          subtitle: state?.error,
                          meta: [
                            spec.kind.label,
                            if (running) '${state!.connections} open',
                          ].join(' · '),
                          leading: WgStatusDot(
                            state: dot,
                            subject: spec.summary,
                          ),
                          trailing: running
                              ? WgButton.ghost(
                                  label: 'Stop',
                                  onPressed: () => unawaited(
                                    forwarder.stop(host.id, spec.id),
                                  ),
                                )
                              : WgButton(
                                  label: state?.state == ForwardState.failed
                                      ? 'Retry'
                                      : 'Start',
                                  onPressed:
                                      state?.state == ForwardState.starting
                                      ? null
                                      : () => unawaited(
                                          forwarder.start(host.id, spec),
                                        ),
                                ),
                        );
                      },
                    ),
                ],
                SizedBox(height: context.space.lg),
                Text(
                  'Local and SOCKS forwards listen on 127.0.0.1 only.',
                  style: context.type.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
    );
  }
}
