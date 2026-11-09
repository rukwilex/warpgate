import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

List<FileEntry> filterFileEntries(
  Iterable<FileEntry> entries,
  String filter, {
  required bool showHidden,
}) {
  final query = filter.toLowerCase();
  return [
    for (final entry in entries)
      if ((showHidden || !entry.isHidden) &&
          (query.isEmpty || entry.name.toLowerCase().contains(query)))
        entry,
  ];
}
