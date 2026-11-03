import 'package:meta/meta.dart';
import 'package:warpgate_core/core/data/document_store.dart';

@immutable
class Snippet {
  const new({required this.id, required this.name, required this.body});

  factory fromJson(JsonMap json) => Snippet(
    id: json['id']! as String,
    name: json['name']! as String,
    body: json['body']! as String,
  );

  static final _variable = RegExp(
    r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\|\s*([^}]*?))?\s*\}\}',
  );

  final String id;
  final String name;
  final String body;

  List<({String name, String? fallback})> get variables {
    final seen = <String>{};
    return [
      for (final match in _variable.allMatches(body))
        if (seen.add(match.group(1)!))
          (name: match.group(1)!, fallback: match.group(2)),
    ];
  }

  String render(Map<String, String> values) =>
      body.replaceAllMapped(_variable, (match) {
        final name = match.group(1)!;
        return values[name] ?? match.group(2) ?? '';
      });

  JsonMap toJson() => {'id': id, 'name': name, 'body': body};
}
