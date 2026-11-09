import 'package:warpgate_core/actions/action_spec.dart';
import 'package:warpgate_core/core/data/document_store.dart';

abstract final class Shapes {
  static final JsonMap forward = Shape.object({
    'id': Shape.string,
    'host': Shape.string,
    'kind': Shape.string,
    'bind_host': Shape.string,
    'bind_port': Shape.integer,
    'target_host': Shape.string,
    'target_port': Shape.integer,
    'auto_start': Shape.boolean,
    'state': Shape.nullable(Shape.string),
  });

  static final JsonMap host = Shape.object({
    'id': Shape.string,
    'label': Shape.string,
    'address': Shape.string,
    'port': Shape.integer,
    'username': Shape.string,
    'auth': Shape.string,
    'key_id': Shape.nullable(Shape.string),
    'group': Shape.nullable(Shape.string),
    'tags': Shape.list(Shape.string),
    'jump_host_id': Shape.nullable(Shape.string),
    'tmux': Shape.boolean,
    'mcp_permission': Shape.string,
    'status': Shape.string,
  });

  static final JsonMap group = Shape.object({
    'id': Shape.string,
    'name': Shape.string,
    'hosts': Shape.list(Shape.string),
  });

  static final JsonMap key = Shape.object({
    'id': Shape.string,
    'name': Shape.string,
    'algorithm': Shape.string,
    'fingerprint': Shape.string,
    'public_key': Shape.string,
    'created_at': Shape.string,
    'has_passphrase': Shape.boolean,
  });

  static final JsonMap knownHost = Shape.object({
    'endpoint': Shape.string,
    'key_type': Shape.string,
    'fingerprint': Shape.string,
    'added_at': Shape.string,
  });

  static final JsonMap entry = Shape.object({
    'name': Shape.string,
    'path': Shape.string,
    'type': Shape.string,
    'size': Shape.integer,
    'modified': Shape.nullable(Shape.string),
    'mode': Shape.nullable(Shape.string),
    'permissions': Shape.string,
    'owner': Shape.nullable(Shape.string),
    'group': Shape.nullable(Shape.string),
  });

  static final JsonMap transfer = Shape.object({
    'id': Shape.string,
    'name': Shape.string,
    'status': Shape.string,
    'source': Shape.string,
    'target': Shape.string,
    'total_bytes': Shape.integer,
    'done_bytes': Shape.integer,
    'bytes_per_second': Shape.integer,
    'origin': Shape.string,
    'error': Shape.nullable(Shape.string),
  });

  static final JsonMap snippet = Shape.object({
    'id': Shape.string,
    'name': Shape.string,
    'body': Shape.string,
    'variables': Shape.list(Shape.string),
  });

  static final JsonMap session = Shape.object({
    'session_id': Shape.string,
    'host_id': Shape.nullable(Shape.string),
    'host_label': Shape.nullable(Shape.string),
    'workspace': Shape.string,
    'status': Shape.string,
    'opened_by': Shape.string,
  });

  static final JsonMap workspace = Shape.object({
    'id': Shape.string,
    'name': Shape.string,
    'active': Shape.boolean,
    'tabs': Shape.integer,
  });

  static final JsonMap layout = Shape.object({
    'id': Shape.string,
    'name': Shape.string,
    'saved_at': Shape.string,
  });

  static final JsonMap hostRun = Shape.object({
    'host': Shape.string,
    'exit_code': Shape.nullable(Shape.integer),
    'stdout': Shape.string,
    'stderr': Shape.string,
    'duration_ms': Shape.integer,
    'timed_out': Shape.boolean,
    'error': Shape.nullable(Shape.string),
  });

  static final JsonMap setting = Shape.object({
    'key': Shape.string,
    'value': Shape.anything,
    'default': Shape.anything,
    'type': Shape.string,
    'choices': Shape.list(Shape.string),
  });

  static final JsonMap uiDone = Shape.object({
    'done': Shape.boolean,
    'session_id': Shape.nullable(Shape.string),
  });

  static final JsonMap copied = Shape.object({
    'transfers': Shape.list(transfer),
    'failed': Shape.integer,
  });

  static final JsonMap check = Shape.object({
    'name': Shape.string,
    'ok': Shape.boolean,
    'detail': Shape.string,
    'fix': Shape.nullable(Shape.string),
  });
}
