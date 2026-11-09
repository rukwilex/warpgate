import 'package:warpgate/features/sftp/application/file_column.dart';
import 'package:warpgate_core/core/util/format.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

String fileColumnText(FileEntry entry, FileColumn column) => switch (column) {
  FileColumn.size => entry.isDirectory ? '' : Format.bytes(entry.size),
  FileColumn.modified =>
    entry.modified == null ? '' : Format.time(entry.modified!),
  FileColumn.permissions => entry.permissions,
  FileColumn.owner => entry.owner ?? '',
};
