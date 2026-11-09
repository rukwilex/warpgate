import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/support/lookups.dart';
import 'package:warpgate_core/core/data/document_store.dart';

abstract final class SnippetHandlers {
  static final Map<String, ActionHandler> all = {
    'snippets.list': _snippetsList,
    'snippets.add': _snippetsAdd,
    'snippets.edit': _snippetsEdit,
    'snippets.rm': _snippetsRm,
  };

  static Future<JsonMap> _snippetsList(ActionCall call) async => {
    'snippets': (await call.runtime.snippets.all()).map(Json.snippet).toList(),
  };

  static Future<JsonMap> _snippetsAdd(ActionCall call) async {
    final snippet = await call.runtime.snippets.save(
      name: call.string('name'),
      body: call.string('body'),
    );
    return {'id': snippet.id, 'name': snippet.name};
  }

  static Future<JsonMap> _snippetsEdit(ActionCall call) async {
    final rt = call.runtime;
    final current = await Lookups.findSnippet(rt, call.string('snippet'));
    final saved = await rt.snippets.save(
      id: current.id,
      name: call.maybe('name') ?? current.name,
      body: call.maybe('body') ?? current.body,
    );
    return {'id': saved.id, 'name': saved.name};
  }

  static Future<JsonMap> _snippetsRm(ActionCall call) async {
    final snippet = await Lookups.findSnippet(call.runtime, call.string('snippet'));
    await call.runtime.snippets.delete(snippet.id);
    return {'id': snippet.id, 'name': snippet.name};
  }
}
