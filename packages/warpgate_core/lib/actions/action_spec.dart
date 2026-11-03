import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/mcp/data/mcp_protocol.dart';

enum ActionPermission { read, write, destructive }

enum ActionMode { local, prefersApp, app }

enum CompletionKind {
  none,
  command,
  host,
  group,
  hostOrGroup,
  key,
  snippet,
  session,
  workspace,
  layout,
  setting,
  remotePath,
  localOrRemotePath,
  localPath,
  transfer,
  knownHost,
  forward,
}

enum CommandCategory {
  general('General'),
  sessions('Sessions'),
  panes('Panes'),
  workspaces('Workspaces'),
  files('Files'),
  multi('Many hosts'),
  navigation('Go to');

  new(this.label);

  final String label;
}

enum ArgKind { positional, option, flag }

class ArgSpec {
  const new(
    this.name,
    this.summary, {
    required this.kind,
    this.short,
    this.required = false,
    this.variadic = false,
    this.repeatable = false,
    this.valueName,
    this.choices = const [],
    this.defaultValue,
    this.complete = CompletionKind.none,
  });

  final String name;
  final String summary;
  final ArgKind kind;
  final String? short;
  final bool required;
  final bool variadic;
  final bool repeatable;
  final String? valueName;
  final List<String> choices;
  final String? defaultValue;
  final CompletionKind complete;

  bool get isPositional => kind == ArgKind.positional;

  bool get takesValue => kind == ArgKind.option;
}

ArgSpec pos(
  String name,
  String summary, {
  bool required = true,
  bool variadic = false,
  CompletionKind complete = CompletionKind.none,
  List<String> choices = const [],
}) => ArgSpec(
  name,
  summary,
  kind: ArgKind.positional,
  required: required,
  variadic: variadic,
  complete: complete,
  choices: choices,
);

ArgSpec opt(
  String name,
  String summary, {
  String? short,
  String value = 'VALUE',
  bool required = false,
  bool repeatable = false,
  List<String> choices = const [],
  String? defaultValue,
  CompletionKind complete = CompletionKind.none,
}) => ArgSpec(
  name,
  summary,
  kind: ArgKind.option,
  short: short,
  required: required,
  repeatable: repeatable,
  valueName: value,
  choices: choices,
  defaultValue: defaultValue,
  complete: complete,
);

ArgSpec flag(String name, String summary, {String? short}) =>
    ArgSpec(name, summary, kind: ArgKind.flag, short: short);

class TableColumn {
  const new(this.key, this.label, {this.format = ColumnFormat.text});

  final String key;
  final String label;
  final ColumnFormat format;
}

enum ColumnFormat { text, number, bytes, status, time, id }

class TableSpec {
  const new(this.rows, this.columns);

  final String rows;
  final List<TableColumn> columns;
}

class PaletteEntry {
  const new(
    this.id,
    this.title,
    this.category, {
    this.keywords = const [],
    this.args = const {},
  });

  final String id;
  final String title;
  final CommandCategory category;
  final List<String> keywords;
  final Map<String, String> args;
}

class ActionSpec {
  const new({
    required this.name,
    required this.cli,
    required this.title,
    required this.summary,
    required this.permission,
    required this.examples,
    required this.result,
    this.mode = ActionMode.local,
    this.args = const [],
    this.aliases = const [],
    this.table,
    this.text,
    this.confirm,
    this.mcp = const [],
    this.palette = const [],
    this.passthrough = false,
    this.notes,
  });

  final String name;
  final String cli;
  final String title;
  final String summary;
  final ActionPermission permission;
  final ActionMode mode;
  final List<ArgSpec> args;
  final List<String> aliases;
  final List<String> examples;
  final JsonMap result;
  final TableSpec? table;
  final String? text;
  final String? confirm;
  final List<McpToolSpec> mcp;
  final List<PaletteEntry> palette;
  final bool passthrough;
  final String? notes;

  List<String> get path => cli.split(' ');

  String get schemaId => 'warpgate.$name/1';

  List<ArgSpec> get positionals =>
      args.where((arg) => arg.isPositional).toList();

  List<ArgSpec> get options => args.where((arg) => !arg.isPositional).toList();

  bool get isUi => mode == ActionMode.app;

  bool get isDestructive => permission == ActionPermission.destructive;
}

abstract final class Shape {
  static const JsonMap string = {'type': 'string'};
  static const JsonMap integer = {'type': 'integer'};
  static const JsonMap number = {'type': 'number'};
  static const JsonMap boolean = {'type': 'boolean'};
  static const JsonMap anything = {};

  static JsonMap nullable(JsonMap shape) => {
    ...shape,
    'nullable': true,
  };

  static JsonMap list(JsonMap items) => {'type': 'array', 'items': items};

  static JsonMap object(Map<String, JsonMap> properties) => {
    'type': 'object',
    'properties': properties,
  };

  static List<String> validate(
    Object? value,
    JsonMap shape, [
    String path = r'$',
  ]) {
    if (value == null) {
      return shape['nullable'] == true || shape.isEmpty
          ? const []
          : ['$path is null'];
    }
    final type = shape['type'];
    switch (type) {
      case 'string':
        return value is String ? const [] : ['$path is not a string'];
      case 'integer':
        return value is int ? const [] : ['$path is not an integer'];
      case 'number':
        return value is num ? const [] : ['$path is not a number'];
      case 'boolean':
        return value is bool ? const [] : ['$path is not a boolean'];
      case 'array':
        if (value is! List) return ['$path is not an array'];
        return [
          for (final (index, item) in value.indexed)
            ...validate(item, (shape['items']! as Map).cast(), '$path[$index]'),
        ];
      case 'object':
        if (value is! Map) return ['$path is not an object'];
        final properties = (shape['properties']! as Map).cast<String, Object?>();
        return [
          for (final MapEntry(:key, value: child) in properties.entries)
            if (value.containsKey(key))
              ...validate(value[key], (child! as Map).cast(), '$path.$key')
            else if ((child as Map)['nullable'] != true)
              '$path.$key is missing',
        ];
      default:
        return const [];
    }
  }
}
