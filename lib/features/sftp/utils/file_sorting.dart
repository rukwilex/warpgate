import 'package:warpgate/features/sftp/application/file_column.dart';
import 'package:warpgate/features/sftp/application/file_sort_key.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

abstract final class FileSorting {
  static int compare(
    FileEntry a,
    FileEntry b,
    SortKey key, {
    required bool ascending,
  }) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    final result = switch (key) {
      SortKey.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      SortKey.size => a.size.compareTo(b.size),
      SortKey.modified => (a.modified ?? DateTime(0)).compareTo(
        b.modified ?? DateTime(0),
      ),
      SortKey.permissions => (a.mode ?? 0).compareTo(b.mode ?? 0),
      SortKey.owner => (a.owner ?? '').compareTo(b.owner ?? ''),
    };
    final tieBroken = result == 0
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : result;
    return ascending ? tieBroken : -tieBroken;
  }

  static List<FileEntry> sorted(
    Iterable<FileEntry> entries,
    SortKey key, {
    required bool ascending,
  }) {
    final keyed =
        [for (final entry in entries) (entry, entry.name.toLowerCase())]
          ..sort((x, y) {
            final a = x.$1;
            final b = y.$1;
            if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
            final result = switch (key) {
              SortKey.name => x.$2.compareTo(y.$2),
              SortKey.size => a.size.compareTo(b.size),
              SortKey.modified => (a.modified ?? DateTime(0)).compareTo(
                b.modified ?? DateTime(0),
              ),
              SortKey.permissions => (a.mode ?? 0).compareTo(b.mode ?? 0),
              SortKey.owner => (a.owner ?? '').compareTo(b.owner ?? ''),
            };
            final tieBroken = result == 0 ? x.$2.compareTo(y.$2) : result;
            return ascending ? tieBroken : -tieBroken;
          });
    return [for (final item in keyed) item.$1];
  }

  static List<FileColumn> visible({
    required double available,
    required double nameMin,
    required double Function(FileColumn column) widthOf,
  }) {
    final columns = [...FileColumn.values];
    double used() => columns.fold(nameMin, (sum, c) => sum + widthOf(c));
    while (columns.isNotEmpty && used() > available) {
      columns.removeLast();
    }
    return columns;
  }
}
