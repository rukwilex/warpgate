import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/design_system/design_system.dart';

import '../helpers/harness.dart';

Widget _board(BuildContext context) {
  final space = context.space;
  return Padding(
    padding: EdgeInsets.all(space.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final state in WgDotState.values) ...[
              WgStatusDot(state: state),
              SizedBox(width: space.xs),
              Text(state.label, style: context.type.caption),
              SizedBox(width: space.lg),
            ],
          ],
        ),
        SizedBox(height: space.xl),
        Wrap(
          spacing: space.sm,
          runSpacing: space.sm,
          children: [
            WgButton.primary(
              label: 'Add host',
              icon: WgIcons.plus,
              onPressed: () {},
            ),
            WgButton(
              label: 'Test connection',
              icon: WgIcons.plug,
              onPressed: () {},
            ),
            WgButton.ghost(label: 'Cancel', onPressed: () {}),
            WgButton.danger(label: 'Delete host', onPressed: () {}),
            const WgButton(label: 'Disabled', onPressed: null),
            WgButton(
              label: 'New terminal',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyT,
                meta: true,
              ),
              onPressed: () {},
            ),
          ],
        ),
        SizedBox(height: space.xl),
        Row(
          children: [
            const WgKeycap(
              SingleActivator(LogicalKeyboardKey.keyK, meta: true),
            ),
            SizedBox(width: space.md),
            const WgKeycap(
              SingleActivator(
                LogicalKeyboardKey.arrowLeft,
                control: true,
                alt: true,
              ),
            ),
            SizedBox(width: space.md),
            const WgTag('Broadcast'),
            SizedBox(width: space.md),
            const WgTag('Claude Code'),
          ],
        ),
        SizedBox(height: space.xl),
        SizedBox(
          width: 420,
          child: Column(
            children: [
              WgListRow(
                title: 'prod-db-1',
                subtitle: 'ops@10.0.4.21',
                meta: '#db  tmux',
                leading: const WgStatusDot(state: WgDotState.connected),
                selected: true,
                onPressed: () {},
              ),
              WgListRow(
                title: 'edge-lb-2',
                subtitle: 'root@edge-lb-2.internal',
                leading: const WgStatusDot(state: WgDotState.reconnecting),
                onPressed: () {},
              ),
              SizedBox(height: space.md),
              const WgInlineMessage(
                tone: WgTone.caution,
                message: 'tmux is not installed on edge-lb-2, so this pane uses a plain shell.',
              ),
              SizedBox(height: space.md),
              const WgProgressBar(label: 'Transfer', value: 0.62),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('core components, ${brightness.name}', (tester) async {
      tester.view
        ..physicalSize = const Size(1000, 560)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(const Builder(builder: _board), brightness: brightness),
      );
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('components_${brightness.name}.png'),
      );
    });
  }
}
