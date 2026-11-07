import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/design_system/design_system.dart';

import '../helpers/harness.dart';

void main() {
  testWidgets('a reconnecting dot steps on a timer instead of every frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Center(child: WgStatusDot(state: WgDotState.reconnecting)),
      ),
    );
    await tester.pump();
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    var frames = 0;
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (SchedulerBinding.instance.hasScheduledFrame) frames++;
    }
    expect(frames, 0);
    await tester.pumpWidget(themed(const SizedBox()));
  });

  testWidgets('a hidden reconnecting dot stops stepping', (tester) async {
    await tester.pumpWidget(
      themed(
        const TickerMode(
          enabled: false,
          child: WgStatusDot(state: WgDotState.reconnecting),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
