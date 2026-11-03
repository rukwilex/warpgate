import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/sftp/presentation/endpoint_providers.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/features/workspace/domain/pane.dart';

import '../goldens/screens_golden_test.dart'
    show FakeResolver, fakeTerminals, start;
import '../helpers/harness.dart';
import '../screens/render_screens_test.dart' show seedHosts;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'session view with files meets guidelines, ${brightness.name}',
      (tester) async {
        final handle = tester.ensureSemantics();
        final container = await pumpApp(
          tester,
          overrides: [
            sessionAutoStartProvider.overrideWithValue(false),
            endpointResolverProvider.overrideWith(FakeResolver.new),
          ],
        );
        await seedHosts(container);
        container.read(workbenchProvider.notifier)
          ..openPane(
            const SshTerminalContent(
              hostId: 'prod-db-1',
              tmuxSession: 'ops',
              files: AttachedFiles(open: true, path: '/home/ops', tree: true),
            ),
          )
          ..openPane(
            const SftpContent(
              left: SftpSide(hostId: 'nas', path: '/home/ops'),
            ),
            placement: PanePlacement.splitRight,
          );
        container.read(routerProvider).go(Routes.workbench);
        await tester.settleFor();
        await fakeTerminals(container);
        await tester.settleFor();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }

  testWidgets(
    'files panel is fully usable from the keyboard',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      final container = await start(
        tester,
        const Size(1280, 800),
        Brightness.dark,
      );
      container
          .read(workbenchProvider.notifier)
          .openPane(
            const SftpContent(
              left: SftpSide(hostId: 'nas', path: '/home/ops'),
            ),
          );
      await tester.settleFor();
      void expectSelected(String label) => expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^$label'))),
        isSemantics(isSelected: true),
      );
      await tester.tap(find.text('deploy'));
      await tester.pump();
      expectSelected('Folder deploy');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expectSelected('Folder logs');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      expectSelected('File notes.md');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expectSelected('File notes.md');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expectSelected('Folder deploy');
    },
  );
}
