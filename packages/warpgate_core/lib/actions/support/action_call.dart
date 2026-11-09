import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';

class ActionCall {
  new(this.runtime, this.args, {this.confirm});

  final WarpgateRuntime runtime;
  final JsonMap args;
  final Future<bool> Function(String message)? confirm;

  String string(String name) => args[name]! as String;

  String? maybe(String name) => args[name] as String?;

  bool on(String name) => args[name] == true;

  List<String> list(String name) =>
      ((args[name] as List?) ?? const <Object?>[]).cast<String>();
}

typedef ActionHandler = Future<JsonMap> Function(ActionCall call);
