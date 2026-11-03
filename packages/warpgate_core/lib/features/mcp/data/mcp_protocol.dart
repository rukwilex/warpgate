import 'dart:convert';

import 'package:warpgate_core/core/data/document_store.dart';

abstract final class McpVersions {
  static const latest = '2026-07-28';
  static const supported = [
    '2026-07-28',
    '2025-11-25',
    '2025-06-18',
    '2025-03-26',
  ];
  static const legacyDefault = '2025-03-26';

  static String negotiate(String? requested) =>
      requested != null && supported.contains(requested) ? requested : latest;

  static bool isStateless(String version) =>
      version.compareTo('2026-01-01') > 0;
}

abstract final class JsonRpcCodes {
  static const parseError = -32700;
  static const invalidRequest = -32600;
  static const methodNotFound = -32601;
  static const invalidParams = -32602;
  static const internalError = -32603;
  static const unsupportedVersion = -32022;
}

class McpError implements Exception {
  const new(this.code, this.message, [this.data]);

  final int code;
  final String message;
  final Object? data;
}

class ToolFailure implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

class McpToolSpec {
  const new({
    required this.name,
    required this.title,
    required this.description,
    required this.properties,
    this.required = const [],
    this.readOnly = false,
    this.destructive = false,
  });

  final String name;
  final String title;
  final String description;
  final JsonMap properties;
  final List<String> required;
  final bool readOnly;
  final bool destructive;

  JsonMap toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': {
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
      'additionalProperties': false,
    },
    'annotations': {
      'title': title,
      'readOnlyHint': readOnly,
      'destructiveHint': destructive,
      'openWorldHint': true,
    },
  };
}

abstract final class ToolArgs {
  static String string(JsonMap args, String key) {
    final value = args[key];
    if (value is String && value.isNotEmpty) return value;
    throw ToolFailure('"$key" is required and must be a non-empty string');
  }

  static String? optionalString(JsonMap args, String key) {
    final value = args[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static int integer(
    JsonMap args,
    String key, {
    required int fallback,
    int? min,
    int? max,
  }) {
    final value = args[key];
    var result = value is num ? value.toInt() : fallback;
    if (min != null && result < min) result = min;
    if (max != null && result > max) result = max;
    return result;
  }

  static List<String>? stringList(JsonMap args, String key) {
    final value = args[key];
    if (value is List) return value.whereType<String>().toList();
    return null;
  }
}

JsonMap toolResult(Object? payload, {bool isError = false}) {
  final text = payload is String
      ? payload
      : const JsonEncoder.withIndent('  ').convert(payload);
  return {
    'resultType': 'complete',
    'content': [
      {'type': 'text', 'text': text},
    ],
    if (payload is Map<String, Object?>) 'structuredContent': payload,
    'isError': isError,
  };
}

JsonMap rpcResult(Object? id, JsonMap result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

JsonMap rpcError(Object? id, int code, String message, [Object? data]) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': message, 'data': ?data},
};
