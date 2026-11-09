import 'package:warpgate/design_system/design_system.dart';

abstract final class SessionStatusDot {
  static WgDotState fromStatus(String status) => switch (status) {
    'connected' => WgDotState.connected,
    'connecting' => WgDotState.connecting,
    'reconnecting' => WgDotState.reconnecting,
    'busy' => WgDotState.busy,
    'dropped' => WgDotState.dropped,
    _ => WgDotState.idle,
  };
}
