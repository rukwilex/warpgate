import 'package:collection/collection.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';

extension ForwardLookup on List<ActiveForward> {
  ActiveForward? find(String hostId, String specId) => firstWhereOrNull(
    (forward) => forward.hostId == hostId && forward.spec.id == specId,
  );
}
