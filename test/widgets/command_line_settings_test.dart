import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/cli/presentation/command_line_settings.dart';

class FakeInstaller extends CliInstaller {
  new({this.bundled = true, this.path});

  final bool bundled;
  String? path;
  int installs = 0;
  int uninstalls = 0;

  @override
  bool get isBundled => bundled;

  @override
  Future<String?> installedPath() async => path;

  @override
  Future<String> install() async {
    installs++;
    return path = '/usr/local/bin/warpgate';
  }

  @override
  Future<void> uninstall() async {
    uninstalls++;
    path = null;
  }
}

Widget host(CliInstaller installer) => MaterialApp(
  theme: WgTheme.build(brightness: Brightness.dark),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: CommandLineSettings(installer: installer),
    ),
  ),
);

void main() {
  testWidgets('a build without the command says so and offers nothing', (tester) async {
    await tester.pumpWidget(host(FakeInstaller(bundled: false)));
    expect(find.text('This build does not include the command'), findsOneWidget);
    expect(find.text('Install warpgate command'), findsNothing);
  });

  testWidgets('install then uninstall', (tester) async {
    final installer = FakeInstaller();
    await tester.pumpWidget(host(installer));
    await tester.pump();
    expect(find.text('Not on your PATH yet'), findsOneWidget);
    await tester.tap(find.text('Install warpgate command'));
    await tester.pump();
    await tester.pump();
    expect(installer.installs, 1);
    expect(find.text('/usr/local/bin/warpgate'), findsOneWidget);
    expect(find.text('Install warpgate command'), findsNothing);
    await tester.tap(find.text('Uninstall'));
    await tester.pump();
    await tester.pump();
    expect(installer.uninstalls, 1);
    expect(find.text('Install warpgate command'), findsOneWidget);
  });

  testWidgets('a folder that may not be on PATH offers the admin install', (tester) async {
    final installer = FakeInstaller(path: '/home/me/.local/bin/warpgate');
    await tester.pumpWidget(host(installer));
    await tester.pump();
    expect(find.text('Install for all users'), findsOneWidget);
    expect(find.textContaining('/home/me/.local/bin to your PATH'), findsOneWidget);
  });
}
