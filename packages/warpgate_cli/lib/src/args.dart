import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

class GlobalOptions {
  bool help = false;
  bool version = false;
  bool json = false;
  bool quiet = false;
  bool noColor = false;
  bool yes = false;
  bool verbose = false;
  bool noApp = false;
  String? profile;
}

class ParsedCommand {
  const new(this.globals, this.action, this.values, {this.group});

  final GlobalOptions globals;
  final ActionSpec? action;
  final Map<String, Object?> values;
  final String? group;
}

abstract final class Suggest {
  static int distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = [i + 1];
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        final best = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
        current.add(best);
      }
      previous = current;
    }
    return previous[b.length];
  }

  static String? closest(String word, Iterable<String> options) {
    String? best;
    var bestScore = 1 << 30;
    for (final option in options) {
      final score = distance(word, option);
      if (score < bestScore) {
        bestScore = score;
        best = option;
      }
    }
    final limit = (word.length / 2).ceil().clamp(1, 3);
    return bestScore <= limit ? best : null;
  }
}

abstract final class CommandTree {
  static final Map<String, ActionSpec> paths = {
    for (final action in ActionRegistry.all) ...{
      action.cli: action,
      for (final alias in action.aliases) alias: action,
    },
  };

  static final Set<String> groups = {
    for (final path in paths.keys)
      if (path.contains(' ')) path.split(' ').first,
  };

  static List<ActionSpec> inGroup(String group) => [
    for (final action in ActionRegistry.all)
      if (action.cli.startsWith('$group ')) action,
    for (final MapEntry(:key, :value) in paths.entries)
      if (key.startsWith('$group ') && !value.cli.startsWith('$group ')) value,
  ];

  static ActionSpec? longest(List<String> words) {
    for (var size = words.length; size > 0; size--) {
      final found = paths[words.take(size).join(' ')];
      if (found != null) return found;
    }
    return null;
  }

  static int pathLength(List<String> words) {
    for (var size = words.length; size > 0; size--) {
      if (paths.containsKey(words.take(size).join(' '))) return size;
    }
    return 0;
  }
}

abstract final class ArgParser {
  static const _globalValue = {'--profile'};

  static bool _setGlobal(GlobalOptions globals, String token) {
    switch (token) {
      case '-h':
      case '--help':
        globals.help = true;
      case '--version':
        globals.version = true;
      case '--json':
        globals.json = true;
      case '--quiet':
        globals.quiet = true;
      case '--no-color':
        globals.noColor = true;
      case '-y':
      case '--yes':
        globals.yes = true;
      case '-v':
      case '--verbose':
        globals.verbose = true;
      case '--no-app':
        globals.noApp = true;
      default:
        return false;
    }
    return true;
  }

  static Never _usage(String message, {String? hint}) =>
      throw ActionFailure(message, kind: ExitKind.usage, hint: hint);

  static ParsedCommand parse(List<String> argv) {
    final globals = GlobalOptions();
    final words = <String>[];
    var index = 0;
    while (index < argv.length) {
      final token = argv[index];
      if (token == '--install' || token == '--uninstall') {
        words.add(token.substring(2));
        index++;
        continue;
      }
      if (_globalValue.contains(token)) {
        if (index + 1 >= argv.length) _usage('$token needs a value');
        globals.profile = argv[index + 1];
        index += 2;
        continue;
      }
      if (token.startsWith('--profile=')) {
        globals.profile = token.substring(10);
        index++;
        continue;
      }
      if (_setGlobal(globals, token)) {
        index++;
        continue;
      }
      break;
    }
    final rest = argv.sublist(index);
    final leading = <String>[];
    for (final token in rest) {
      if (token.startsWith('-')) break;
      leading.add(token);
    }
    final size = CommandTree.pathLength(leading);
    if (size == 0) {
      if (words.isNotEmpty) {
        return ParsedCommand(globals, CommandTree.paths[words.first], const {});
      }
      if (rest.isEmpty) return ParsedCommand(globals, null, const {});
      if (leading.isNotEmpty && CommandTree.groups.contains(leading.first)) {
        if (leading.length == 1) {
          _parseGlobalsOnly(rest.sublist(1), globals);
          return ParsedCommand(globals, null, const {}, group: leading.first);
        }
        final options = CommandTree.inGroup(leading.first)
            .map((action) => action.cli.split(' ').last);
        final near = Suggest.closest(leading[1], options);
        _usage(
          '"${leading.take(2).join(' ')}" is not a command',
          hint: near == null
              ? 'Run warpgate ${leading.first} --help to see its commands'
              : 'Did you mean warpgate ${leading.first} $near?',
        );
      }
      if (rest.first.startsWith('-')) {
        _usage(
          'Unknown flag ${rest.first}',
          hint: 'Run warpgate --help to see the flags',
        );
      }
      final near = Suggest.closest(rest.first, {
        ...CommandTree.paths.keys.map((path) => path.split(' ').first),
      });
      _usage(
        '"${rest.first}" is not a command',
        hint: near == null
            ? 'Run warpgate --help to see the commands'
            : 'Did you mean warpgate $near?',
      );
    }
    final action = CommandTree.paths[leading.take(size).join(' ')]!;
    return ParsedCommand(
      globals,
      action,
      parseValues(action, rest.sublist(size), globals),
    );
  }

  static void _parseGlobalsOnly(List<String> tokens, GlobalOptions globals) {
    for (final token in tokens) {
      if (!_setGlobal(globals, token)) {
        _usage('Unknown flag $token');
      }
    }
  }

  static Map<String, Object?> parseValues(
    ActionSpec action,
    List<String> tokens,
    GlobalOptions globals,
  ) {
    final values = <String, Object?>{};
    final positional = <String>[];
    final byLong = {for (final arg in action.options) arg.name: arg};
    final byShort = {
      for (final arg in action.options)
        if (arg.short != null) arg.short!: arg,
    };
    void store(ArgSpec arg, String value) {
      if (arg.choices.isNotEmpty && !arg.choices.contains(value)) {
        _usage(
          '--${arg.name} must be one of: ${arg.choices.join(', ')}',
        );
      }
      if (arg.repeatable) {
        (values[arg.name] ??= <String>[]) as List<String>;
        (values[arg.name]! as List<String>).add(value);
      } else {
        values[arg.name] = value;
      }
    }

    final lastPositional = action.positionals.isEmpty
        ? null
        : action.positionals.last;
    final stopAt = action.passthrough ? action.positionals.length - 1 : null;
    List<String>? afterDashes;
    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token == '--') {
        afterDashes = tokens.sublist(i + 1);
        break;
      }
      if (stopAt != null &&
          positional.length >= stopAt &&
          action.positionals[stopAt - (stopAt == 0 ? 0 : 1)].variadic == false &&
          !token.startsWith('-')) {
        afterDashes = tokens.sublist(i);
        break;
      }
      if (!token.startsWith('-') || token == '-') {
        positional.add(token);
        i++;
        continue;
      }
      if (token.startsWith('--')) {
        final equals = token.indexOf('=');
        final name = equals < 0 ? token.substring(2) : token.substring(2, equals);
        final arg = byLong[name];
        if (arg == null) {
          if (equals < 0 && _setGlobal(globals, token)) {
            i++;
            continue;
          }
          if (name == 'profile') {
            if (equals >= 0) {
              globals.profile = token.substring(equals + 1);
              i++;
            } else {
              if (i + 1 >= tokens.length) _usage('--profile needs a value');
              globals.profile = tokens[i + 1];
              i += 2;
            }
            continue;
          }
          final near = Suggest.closest(name, byLong.keys);
          _usage(
            'Unknown flag --$name',
            hint: near == null
                ? 'Run warpgate ${action.cli} --help to see its flags'
                : 'Did you mean --$near?',
          );
        }
        if (!arg.takesValue) {
          if (equals >= 0) _usage('--$name does not take a value');
          values[name] = true;
          i++;
          continue;
        }
        if (equals >= 0) {
          store(arg, token.substring(equals + 1));
          i++;
        } else {
          if (i + 1 >= tokens.length) _usage('--$name needs a value');
          store(arg, tokens[i + 1]);
          i += 2;
        }
        continue;
      }
      var cluster = token.substring(1);
      var consumedNext = false;
      while (cluster.isNotEmpty) {
        final letter = cluster[0];
        cluster = cluster.substring(1);
        final arg = byShort[letter];
        if (arg == null) {
          if (_setGlobal(globals, '-$letter')) continue;
          _usage(
            'Unknown flag -$letter',
            hint: 'Run warpgate ${action.cli} --help to see its flags',
          );
        }
        if (!arg.takesValue) {
          values[arg.name] = true;
          continue;
        }
        if (cluster.isNotEmpty) {
          store(arg, cluster);
          cluster = '';
        } else {
          if (i + 1 >= tokens.length) _usage('-$letter needs a value');
          store(arg, tokens[i + 1]);
          consumedNext = true;
        }
      }
      i += consumedNext ? 2 : 1;
    }
    if (globals.help) return values;

    final slots = action.positionals;
    final variadicIndex = slots.indexWhere((slot) => slot.variadic);
    var cursor = 0;
    if (action.passthrough && afterDashes != null && lastPositional != null) {
      final head = slots.sublist(0, slots.length - 1);
      for (final slot in head) {
        if (slot.variadic) {
          values[slot.name] = positional.sublist(cursor);
          cursor = positional.length;
        } else if (cursor < positional.length) {
          values[slot.name] = positional[cursor++];
        } else if (slot.required) {
          _usage('Name the ${slot.name}', hint: _usageHint(action));
        }
      }
      if (cursor < positional.length) {
        _usage('Too many arguments: ${positional[cursor]}', hint: _usageHint(action));
      }
      values[lastPositional.name] = afterDashes;
    } else {
      if (afterDashes != null) positional.addAll(afterDashes);
      for (final (slotIndex, slot) in slots.indexed) {
        if (slot.variadic) {
          final remainingSlots = slots.length - slotIndex - 1;
          final end = positional.length - remainingSlots;
          values[slot.name] = positional.sublist(cursor, end < cursor ? cursor : end);
          cursor = end < cursor ? cursor : end;
          continue;
        }
        if (cursor < positional.length) {
          final value = positional[cursor++];
          if (slot.choices.isNotEmpty && !slot.choices.contains(value)) {
            _usage('${slot.name} must be one of: ${slot.choices.join(', ')}');
          }
          values[slot.name] = value;
        }
      }
      if (cursor < positional.length && variadicIndex < 0) {
        _usage('Too many arguments: ${positional[cursor]}', hint: _usageHint(action));
      }
    }
    for (final slot in slots) {
      final value = values[slot.name];
      final empty = value == null || (value is List && value.isEmpty);
      if (slot.required && empty) {
        _usage('Name the ${slot.name}', hint: _usageHint(action));
      }
    }
    for (final arg in action.options) {
      if (arg.required && values[arg.name] == null) {
        _usage('--${arg.name} is required', hint: _usageHint(action));
      }
      if (arg.defaultValue != null && values[arg.name] == null) {
        values[arg.name] = arg.defaultValue;
      }
    }
    return values;
  }

  static String _usageHint(ActionSpec action) =>
      'Run warpgate ${action.cli} --help for usage';
}

abstract final class Durations {
  static Duration? parse(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d+)(ms|s|m|h)?$').firstMatch(value);
    if (match == null) {
      throw ActionFailure(
        'Could not read the time "$value". Use a form like 30s or 5m',
        kind: ExitKind.usage,
      );
    }
    final amount = int.parse(match.group(1)!);
    return switch (match.group(2)) {
      'ms' => Duration(milliseconds: amount),
      'm' => Duration(minutes: amount),
      'h' => Duration(hours: amount),
      _ => Duration(seconds: amount),
    };
  }
}
