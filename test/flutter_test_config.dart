import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('Geist', [
    'assets/fonts/Geist-Regular.ttf',
    'assets/fonts/Geist-Medium.ttf',
    'assets/fonts/Geist-SemiBold.ttf',
  ]);
  await _load('JetBrainsMono', [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Medium.ttf',
  ]);
  await _load('packages/lucide_icons_flutter/Lucide300', [
    '${_packageRoot('lucide_icons_flutter')}/assets/build_font/LucideVariable-w300.ttf',
  ]);
  await testMain();
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();
}

String _packageRoot(String name) {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final packages = (config['packages']! as List).cast<Map<String, Object?>>();
  final entry = packages.firstWhere((package) => package['name'] == name);
  return Uri.parse(entry['rootUri']! as String).toFilePath();
}
