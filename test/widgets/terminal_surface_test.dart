import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';
import 'package:warpgate/features/terminal/presentation/terminal_surface.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/hosts/data/host_repository.dart';
import 'package:warpgate_core/features/keys/data/key_repository.dart';
import 'package:xterm/xterm.dart';

import '../helpers/harness.dart';

TerminalSession localSession() {
  final store = DriftDocumentStore(AppDatabase(NativeDatabase.memory()));
  final secrets = MemorySecretStore();
  return TerminalSession(
    id: 'pane',
    target: const LocalTarget(),
    pool: ConnectionPool(
      lookup: (_) => null,
      hosts: HostRepository(store, secrets),
      keys: KeyRepository(store, secrets),
      broker: InteractionBroker(),
    ),
  );
}

void main() {
  testWidgets('grid follows the area, never clips a column, reflows text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1000, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = localSession();
    final controller = TerminalController();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var width = 600.0;
    late StateSetter update;
    await tester.pumpWidget(
      themed(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 300,
                child: TerminalSurface(
                  session: session,
                  controller: controller,
                  focusNode: focus,
                  theme: TerminalThemes.defaultTheme,
                  cursorType: TerminalCursorType.block,
                  fontSize: 13,
                  onFontSize: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final terminal = session.terminal;
    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    final cell = TerminalSurface.measureCell(view.textStyle, view.textScaler!);
    final padding = view.padding!;
    expect(
      terminal.viewWidth * cell.width + padding.horizontal,
      closeTo(width, 0.01),
    );
    expect(
      terminal.viewHeight * cell.height + padding.vertical,
      closeTo(300, 0.01),
    );
    expect(padding.left, greaterThanOrEqualTo(minimumPadding(tester)));
    final wide = terminal.viewWidth;
    terminal.write('x' * (wide + 5));
    update(() => width = 300);
    await tester.pump();
    expect(terminal.viewWidth, lessThan(wide));
    final lines = terminal.mainBuffer.lines;
    final text = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      text.write(lines[i].getText().replaceAll('\u0000', ''));
    }
    expect(text.toString().replaceAll(' ', ''), 'x' * (wide + 5));
    update(() => width = 4);
    await tester.pump();
    expect(terminal.viewWidth, greaterThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}

double minimumPadding(WidgetTester tester) {
  final context = tester.element(find.byType(TerminalSurface));
  return context.sizes.terminalPadding - 0.01;
}
