import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';

bool completedTransfersTouch(
  List<TransferJob> previous,
  List<TransferJob> next, {
  required String? hostId,
  required String path,
  required p.Context? paths,
}) => next.any((job) {
  if (job.status != TransferStatus.completed) return false;
  final before = previous.firstWhereOrNull((item) => item.id == job.id);
  if (before?.status == TransferStatus.completed) return false;
  final target = job.target;
  final source = job.source;
  return (target.hostId == hostId && paths?.dirname(target.path) == path) ||
      (job.move &&
          source.hostId == hostId &&
          paths?.dirname(source.path) == path);
});
