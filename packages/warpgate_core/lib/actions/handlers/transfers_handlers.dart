import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/actions/support/json_views.dart';
import 'package:warpgate_core/actions/support/lookups.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

abstract final class TransferHandlers {
  static final Map<String, ActionHandler> all = {
    'transfers.list': _transfersList,
    'transfers.pause': _transfersPause,
    'transfers.cancel': _transfersCancel,
    'transfers.clear': _transfersClear,
  };

  static Future<JsonMap> _transfersList(ActionCall call) async {
    final rt = call.runtime;
    final status = call.maybe('status');
    final jobs = await Lookups.jobs(rt);
    return {
      'transfers': [
        for (final job in jobs)
          if (status == null || job.status.name == status) Json.transfer(rt, job),
      ],
    };
  }

  static Future<void> _save(WarpgateRuntime rt, TransferJob job) =>
      rt.store.put(TransferScheduler.collection, job.id, job.toJson(), at: job.createdAt);

  static Future<JsonMap> _transfersPause(ActionCall call) async {
    final rt = call.runtime;
    final job = await Lookups.findJob(rt, call.string('id'));
    if (job.status == TransferStatus.running && job.ownerPid != null) {
      await rt.store.put(TransferScheduler.controlCollection, job.id, {'action': 'pause'});
    } else {
      await _save(rt, job.copyWith(status: TransferStatus.paused));
    }
    return {'id': job.id};
  }

  static Future<JsonMap> _transfersCancel(ActionCall call) async {
    final rt = call.runtime;
    final job = await Lookups.findJob(rt, call.string('id'));
    if (job.status == TransferStatus.running && job.ownerPid != null) {
      await rt.store.put(TransferScheduler.controlCollection, job.id, {'action': 'cancel'});
    } else {
      await _save(
        rt,
        job.copyWith(status: TransferStatus.canceled, finishedAt: DateTime.now),
      );
    }
    return {'id': job.id};
  }

  static Future<JsonMap> _transfersClear(ActionCall call) async {
    final rt = call.runtime;
    var cleared = 0;
    for (final job in await Lookups.jobs(rt)) {
      if (job.status.isFinished) {
        await rt.store.delete(TransferScheduler.collection, job.id);
        cleared += 1;
      }
    }
    return {'cleared': cleared};
  }
}
