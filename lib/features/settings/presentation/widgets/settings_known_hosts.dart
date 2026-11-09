import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

class SettingsKnownHosts extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsKnownHosts> createState() => _SettingsKnownHostsState();
}

class _SettingsKnownHostsState extends ConsumerState<SettingsKnownHosts> {
  late Future<List<KnownHost>> _future = ref
      .read(hostRepositoryProvider)
      .knownHosts();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<KnownHost>>(
    future: _future,
    builder: (context, snapshot) {
      final hosts = snapshot.data;
      if (hosts == null) return const WgSkeletonList(rows: 2);
      if (hosts.isEmpty) {
        return Text(
          'No trusted host keys yet. They are added when you trust a server on first connect.',
          style: context.type.caption,
        );
      }
      return Column(
        children: [
          for (final host in hosts)
            WgListRow(
              title: host.endpoint,
              subtitle: '${host.keyType}  ${host.fingerprint}',
              dense: true,
              leading: const Icon(WgIcons.fingerprint),
              trailing: WgButton.ghost(
                label: 'Forget',
                onPressed: () async {
                  await ref.read(hostRepositoryProvider).forget(host.endpoint);
                  setState(
                    () =>
                        _future = ref.read(hostRepositoryProvider).knownHosts(),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
