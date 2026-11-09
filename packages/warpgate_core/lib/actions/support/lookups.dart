import 'package:collection/collection.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/targets.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';
import 'package:warpgate_core/features/snippets/domain/snippet.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

abstract final class Lookups {
  static Map<String, String> groupNames(WarpgateRuntime rt) => {
    for (final group in rt.hosts.catalog.groups) group.id: group.name,
  };

  static Host savedHost(ActionCall call, String reference) {
    final host = call.runtime.host(reference);
    if (host.id.startsWith(HostTargets.adHocPrefix)) {
      throw ActionFailure(
        'No saved host called "$reference"',
        kind: ExitKind.notFound,
        hint: 'Run warpgate hosts list to see saved hosts',
      );
    }
    return host;
  }

  static Future<SshKey> findKey(WarpgateRuntime rt, String reference) async {
    final keys = await rt.keys.all();
    final key = keys.firstWhereOrNull(
      (item) => item.id == reference || item.name == reference,
    );
    if (key != null) return key;
    throw ActionFailure(
      'No key called "$reference"',
      kind: ExitKind.notFound,
      hint: 'Run warpgate keys list to see saved keys',
    );
  }

  static Future<List<TransferJob>> jobs(WarpgateRuntime rt) => TransferScheduler.load(rt.store);

  static Future<TransferJob> findJob(WarpgateRuntime rt, String reference) async {
    final jobs = await Lookups.jobs(rt);
    final matches = jobs.where((job) => job.id == reference || job.id.startsWith(reference)).toList();
    if (matches.length == 1) return matches.single;
    throw ActionFailure(
      matches.isEmpty ? 'No transfer "$reference"' : '"$reference" matches several transfers',
      kind: ExitKind.notFound,
      hint: 'Run warpgate transfers list to see them',
    );
  }

  static Future<Snippet> findSnippet(WarpgateRuntime rt, String reference) async {
    final snippets = await rt.snippets.all();
    final found = snippets.firstWhereOrNull((item) => item.id == reference || item.name == reference);
    if (found != null) return found;
    throw ActionFailure(
      'No snippet called "$reference"',
      kind: ExitKind.notFound,
      hint: 'Run warpgate snippets list to see them',
    );
  }
}
