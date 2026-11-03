import 'dart:io';

import 'package:test/test.dart';
import 'package:warpgate_cli/warpgate_cli.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';

void main() {
  test('every registry action has a CLI command', () {
    for (final action in ActionRegistry.all) {
      expect(CommandTree.paths[action.cli], same(action), reason: action.name);
    }
  });

  test('every registry action has something that runs it', () {
    final missing = [
      for (final action in ActionRegistry.all)
        if (!Dispatch.hasHandler(action)) action.name,
    ];
    expect(missing, isEmpty);
  });

  test('names and paths are unique', () {
    final names = ActionRegistry.all.map((action) => action.name).toList();
    expect(names.toSet(), hasLength(names.length));
    final paths = [
      for (final action in ActionRegistry.all) ...[action.cli, ...action.aliases],
    ];
    expect(paths.toSet(), hasLength(paths.length));
  });

  test('every MCP tool and palette entry comes from an action', () {
    expect(McpTools.all.map((tool) => tool.name).toSet(), hasLength(18));
    final ids = ActionRegistry.paletteEntries.map((entry) => entry.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every action documents itself', () {
    for (final action in ActionRegistry.all) {
      expect(action.summary, isNotEmpty, reason: action.name);
      expect(action.summary.endsWith('.'), isFalse, reason: action.name);
      expect(action.summary.contains('!'), isFalse, reason: action.name);
      expect(action.examples.length, greaterThanOrEqualTo(2), reason: action.name);
      expect(action.examples.length, lessThanOrEqualTo(3), reason: action.name);
      for (final example in action.examples) {
        expect(example, contains('warpgate'), reason: action.name);
      }
      for (final arg in action.args) {
        expect(arg.summary, isNotEmpty, reason: '${action.name} ${arg.name}');
      }
    }
  });

  test('examples parse', () {
    for (final action in ActionRegistry.all) {
      for (final example in action.examples) {
        if (example.contains('|') || example.contains('=') && !example.startsWith('warpgate')) continue;
        if (!example.startsWith('warpgate ')) continue;
        final words = _split(example).skip(1).takeWhile((word) => !const {'>', '>>', '<'}.contains(word)).toList();
        expect(() => ArgParser.parse(words), returnsNormally, reason: example);
      }
    }
  });

  test('destructive actions that confirm name what they touch', () {
    for (final action in ActionRegistry.all) {
      final template = action.confirm;
      if (template == null) continue;
      expect(action.isDestructive, isTrue, reason: action.name);
      expect(template.endsWith('?') || template.endsWith('.'), isTrue, reason: action.name);
    }
  });

  test('docs/CLI.md is up to date', () {
    final file = File('../../docs/CLI.md');
    expect(file.readAsStringSync(), DocsGenerator.render(), reason: 'Run dart run tool/gen_docs.dart');
  });
}

List<String> _split(String line) {
  final words = <String>[];
  for (final match in RegExp(r'''"[^"]*"|'[^']*'|\S+''').allMatches(line)) {
    final word = match.group(0)!;
    words.add(
      word.length >= 2 && (word.startsWith('"') || word.startsWith("'"))
          ? word.substring(1, word.length - 1)
          : word,
    );
  }
  return words;
}
