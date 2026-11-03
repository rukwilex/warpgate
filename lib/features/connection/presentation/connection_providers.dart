import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/keys/presentation/keys_controller.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';

final connectionPoolProvider = Provider<ConnectionPool>((ref) {
  final pool = ConnectionPool(
    lookup: ref.watch(hostLookupProvider),
    hosts: ref.watch(hostRepositoryProvider),
    keys: ref.watch(keyRepositoryProvider),
    broker: ref.watch(interactionBrokerProvider),
  );
  ref.onDispose(() => unawaited(pool.dispose()));
  return pool;
});

final hostLinksProvider =
    NotifierProvider<HostLinksController, Map<String, LinkStatus>>(
      HostLinksController.new,
    );

class HostLinksController extends Notifier<Map<String, LinkStatus>> {
  @override
  Map<String, LinkStatus> build() {
    final pool = ref.watch(connectionPoolProvider);
    final subscription = pool.changes.listen((_) => state = pool.statuses);
    ref.onDispose(subscription.cancel);
    return pool.statuses;
  }
}

final portForwarderProvider = Provider<PortForwarder>((ref) {
  final forwarder = PortForwarder(ref.watch(connectionPoolProvider));
  ref.onDispose(() => unawaited(forwarder.dispose()));
  return forwarder;
});

final activeForwardsProvider =
    NotifierProvider<ActiveForwardsController, List<ActiveForward>>(
      ActiveForwardsController.new,
    );

class ActiveForwardsController extends Notifier<List<ActiveForward>> {
  @override
  List<ActiveForward> build() {
    final forwarder = ref.watch(portForwarderProvider);
    final subscription = forwarder.changes.listen(
      (_) => state = forwarder.forwards,
    );
    ref.onDispose(subscription.cancel);
    return forwarder.forwards;
  }
}
