import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/sftp/application/file_sort_key.dart';

enum FileColumn {
  size('Size', SortKey.size),
  modified('Modified', SortKey.modified),
  permissions('Permissions', SortKey.permissions),
  owner('Owner', SortKey.owner);

  new(this.label, this.sort);

  final String label;
  final SortKey sort;

  double defaultWidth(WgSizes sizes) => switch (this) {
    FileColumn.size => sizes.columnSize,
    FileColumn.modified => sizes.columnModified,
    FileColumn.permissions => sizes.columnPermissions,
    FileColumn.owner => sizes.columnOwner,
  };
}
