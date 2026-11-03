import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';

export 'package:warpgate_core/core/interaction/interaction_broker.dart';

final interactionBrokerProvider = Provider<InteractionBroker>((ref) {
  final broker = InteractionBroker();
  ref.onDispose(broker.dispose);
  return broker;
});
