import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:warpgate_cli/warpgate_cli.dart';
import 'package:warpgate_core/actions/registry.dart';

void main() {
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';
  final directory = Directory('test/goldens/help');

  void check(String name, String text) {
    final file = File(p.join(directory.path, '$name.txt'));
    if (update) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'Run UPDATE_GOLDENS=1 dart test test/help_golden_test.dart');
    expect(text, file.readAsStringSync(), reason: 'Help text changed for $name');
  }

  test('root', () => check('warpgate', Help.root()));

  for (final group in CommandTree.groups) {
    test('group $group', () => check('group-$group', Help.forGroup(group)));
  }

  for (final action in ActionRegistry.all) {
    test(action.cli, () {
      check(action.cli.replaceAll(' ', '-'), Help.forAction(action));
    });
  }

  test('warpgate help X and X --help show the same text', () {
    for (final action in ActionRegistry.all) {
      expect(Help.resolve(action.path), Help.forAction(action), reason: action.cli);
    }
  });

  test('no stray golden files', () {
    final expected = {
      'warpgate.txt',
      for (final group in CommandTree.groups) 'group-$group.txt',
      for (final action in ActionRegistry.all) '${action.cli.replaceAll(' ', '-')}.txt',
    };
    final actual = directory.listSync().map((item) => p.basename(item.path)).toSet();
    expect(actual, expected);
  });
}
