import 'package:warpgate_core/features/connection/domain/link_state.dart';

LinkState worstState(Iterable<LinkState> states) {
  const order = [
    LinkState.dropped,
    LinkState.reconnecting,
    LinkState.connecting,
    LinkState.busy,
    LinkState.connected,
    LinkState.idle,
  ];
  final list = states.toList();
  if (list.isEmpty) return LinkState.idle;
  return order.firstWhere(list.contains, orElse: () => LinkState.idle);
}
