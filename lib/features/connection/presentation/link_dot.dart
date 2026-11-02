import 'package:warpgate/design_system/components/wg_status_dot.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';

extension LinkDot on LinkState {
  WgDotState get dot => switch (this) {
    LinkState.idle => WgDotState.idle,
    LinkState.connecting => WgDotState.connecting,
    LinkState.connected => WgDotState.connected,
    LinkState.busy => WgDotState.busy,
    LinkState.reconnecting => WgDotState.reconnecting,
    LinkState.dropped => WgDotState.dropped,
  };
}
