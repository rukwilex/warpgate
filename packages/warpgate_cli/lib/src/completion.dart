import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/args.dart';
import 'package:warpgate_cli/src/secrets/cli_secrets.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/features/settings/data/settings_store.dart';
import 'package:warpgate_core/ipc/ipc.dart';

abstract final class Completion {
  static String script(String shell) => switch (shell) {
    'bash' => r'''
_warpgate_complete() {
  local IFS=$'\n'
  COMPREPLY=($(warpgate __complete "${COMP_WORDS[@]:1:COMP_CWORD}" 2>/dev/null))
}
complete -o nospace -o default -F _warpgate_complete warpgate
''',
    'zsh' => r'''
#compdef warpgate
_warpgate() {
  local -a items
  items=("${(@f)$(warpgate __complete "${words[@]:1:$((CURRENT-1))}" 2>/dev/null)}")
  compadd -S '' -- "${items[@]}"
}
compdef _warpgate warpgate
''',
    'fish' => '''
complete -c warpgate -f -a '(warpgate __complete (commandline -opc)[2..-1] (commandline -ct) 2>/dev/null)'
''',
    _ => r'''
Register-ArgumentCompleter -Native -CommandName warpgate -ScriptBlock {
  param($word, $ast, $cursor)
  $parts = $ast.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() }
  if ($word -eq '') { $parts += '' }
  warpgate __complete @parts 2>$null | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
  }
}
''',
  };

  static Future<int> run(List<String> words) async {
    final candidates = await candidatesFor(words);
    candidates.forEach(stdout.writeln);
    return 0;
  }

  static const _globalFlags = [
    '--help',
    '--version',
    '--json',
    '--quiet',
    '--no-color',
    '--yes',
    '--verbose',
    '--profile',
    '--no-app',
  ];

  static Future<List<String>> candidatesFor(List<String> words) async {
    final current = words.isEmpty ? '' : words.last;
    final before = words.isEmpty ? <String>[] : words.sublist(0, words.length - 1);
    final leading = <String>[];
    var skipNext = false;
    for (final word in before) {
      if (skipNext) {
        skipNext = false;
        continue;
      }
      if (word == '--profile') {
        skipNext = true;
        continue;
      }
      if (word.startsWith('-')) continue;
      leading.add(word);
    }
    final size = CommandTree.pathLength(leading);
    if (size == 0) {
      final next = <String>{
        for (final path in CommandTree.paths.keys)
          if (leading.isEmpty)
            path.split(' ').first
          else if (path.startsWith('${leading.join(' ')} '))
            path.substring(leading.join(' ').length + 1).split(' ').first,
        if (current.startsWith('-')) ..._globalFlags,
      };
      return next.where((item) => item.startsWith(current)).toList()..sort();
    }
    final action = CommandTree.paths[leading.take(size).join(' ')]!;
    final subcommands = <String>{
      for (final path in CommandTree.paths.keys)
        if (path.startsWith('${action.cli} '))
          path.substring(action.cli.length + 1).split(' ').first,
    };
    if (current.startsWith('-')) {
      return [
        for (final option in action.options) '--${option.name}',
        ..._globalFlags,
      ].where((item) => item.startsWith(current)).toList();
    }
    if (before.isNotEmpty && before.last.startsWith('-')) {
      final name = before.last.replaceFirst(RegExp('^-+'), '');
      final option = action.options.where((item) => item.name == name || item.short == name).firstOrNull;
      if (option != null && option.takesValue) {
        if (option.choices.isNotEmpty) {
          return option.choices.where((item) => item.startsWith(current)).toList();
        }
        return await dynamicValues(option.complete, current);
      }
    }
    final used = leading.length - size;
    final slots = action.positionals;
    if (slots.isEmpty) return subcommands.where((item) => item.startsWith(current)).toList();
    final slot = used < slots.length ? slots[used] : slots.last;
    final values = slot.choices.isNotEmpty
        ? slot.choices.where((item) => item.startsWith(current)).toList()
        : await dynamicValues(slot.complete, current);
    return [
      if (used == 0) ...subcommands.where((item) => item.startsWith(current)),
      ...values,
    ];
  }

  static Future<List<String>> dynamicValues(CompletionKind kind, String current) async {
    final paths = AppPaths.resolve();
    if (!File(paths.database).existsSync()) return const [];
    final store = SqliteDocumentStore.open(paths.database);
    try {
      Future<List<String>> names(String collection, String field) async => [
        for (final json in await store.all(collection)) '${json[field]}',
      ];
      final values = switch (kind) {
        CompletionKind.host => await names('hosts', 'label'),
        CompletionKind.group => await names('host_groups', 'name'),
        CompletionKind.hostOrGroup => [
          ...await names('hosts', 'label'),
          for (final group in await names('host_groups', 'name')) '@$group',
        ],
        CompletionKind.key => await names('keys', 'name'),
        CompletionKind.snippet => await names('snippets', 'name'),
        CompletionKind.knownHost => await names('known_hosts', 'endpoint'),
        CompletionKind.transfer => await names('transfers', 'id'),
        CompletionKind.layout => await names('saved_layouts', 'name'),
        CompletionKind.setting => [for (final field in SettingsStore.fields) field.key],
        CompletionKind.command => CommandTree.paths.keys.toList(),
        CompletionKind.session => await _sessions(paths),
        CompletionKind.workspace => await _workspaces(store),
        CompletionKind.forward => await _forwards(store),
        CompletionKind.remotePath || CompletionKind.localOrRemotePath => await _paths(store, paths, current),
        _ => const <String>[],
      };
      return values.where((item) => item.startsWith(current)).toList();
    } finally {
      store.close();
    }
  }

  static Future<List<String>> _workspaces(SqliteDocumentStore store) async {
    final state = await store.get('workbench', 'state');
    return [
      for (final item in (state?['workspaces'] as List?) ?? const <Object?>[])
        if (item is Map) '${item['name']}',
    ];
  }

  static Future<List<String>> _forwards(SqliteDocumentStore store) async => [
    for (final host in await store.all('hosts'))
      for (final item in (host['forwards'] as List?) ?? const <Object?>[])
        if (item is Map) '${item['id']}',
  ];

  static Future<List<String>> _sessions(AppPaths paths) async {
    final client = await IpcClient.connect(paths, timeout: const Duration(milliseconds: 200));
    if (client == null) return const [];
    try {
      final result = await client.call('action', {'name': 'sessions.list', 'args': const <String, Object?>{}});
      return [
        for (final item in (result['sessions'] as List?) ?? const <Object?>[])
          if (item is Map) '${item['session_id']}',
      ];
    } finally {
      await client.close();
    }
  }

  static const cacheLife = Duration(seconds: 30);
  static const remoteLimit = Duration(milliseconds: 1500);

  static Future<List<String>> _paths(SqliteDocumentStore store, AppPaths paths, String current) async {
    final ref = PathRef.parse(current);
    if (!ref.isRemote) {
      return [for (final host in await store.all('hosts')) '${host['label']}:'];
    }
    final slash = ref.path.lastIndexOf('/');
    final folder = slash < 0 ? '~' : ref.path.substring(0, slash + 1);
    final prefix = slash < 0 ? '' : folder;
    final key = base64Url.encode(utf8.encode('${ref.host}:$folder')).replaceAll('=', '');
    final cache = File(p.join(paths.cache, 'paths-$key.json'));
    if (cache.existsSync() && DateTime.now().difference(cache.lastModifiedSync()) < cacheLife) {
      return (jsonDecode(cache.readAsStringSync()) as List).cast<String>();
    }
    final runtime = WarpgateRuntime(
      store: store,
      secrets: CliSecrets(store: store, paths: paths, client: () => IpcClient.connect(paths)),
      broker: InteractionBroker(),
    );
    try {
      await runtime.loadCatalog();
      final host = runtime.host(ref.host!);
      final results = await () async {
        final endpoint = await runtime.endpoints.resolve(host.id);
        final directory = await endpoint.resolve(folder);
        return [
          for (final entry in await endpoint.list(directory))
            '${ref.host}:$prefix${entry.name}${entry.isDirectory ? '/' : ''}',
        ];
      }().timeout(remoteLimit);
      await cache.parent.create(recursive: true);
      await cache.writeAsString(jsonEncode(results));
      return results;
    } on Object {
      return const [];
    } finally {
      unawaited(runtime.close());
    }
  }
}
