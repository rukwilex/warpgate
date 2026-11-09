import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart';

class FileSelection {
  final Set<String> paths = {};
  String? anchor;

  bool get isEmpty => paths.isEmpty;

  bool get isNotEmpty => paths.isNotEmpty;

  bool contains(String path) => paths.contains(path);

  List<FileEntry> entriesIn(List<FileEntry> visible) => [
    for (final entry in visible)
      if (paths.contains(entry.path)) entry,
  ];

  void clear() => paths.clear();

  void reset() {
    paths.clear();
    anchor = null;
  }

  void only(String path) {
    paths
      ..clear()
      ..add(path);
    anchor = path;
  }

  void extend(String path) {
    paths.add(path);
    anchor = path;
  }

  void toggle(String path) {
    if (!paths.remove(path)) paths.add(path);
  }

  void addAll(Iterable<FileEntry> entries) =>
      paths.addAll(entries.map((entry) => entry.path));

  void retainIn(List<FileEntry> entries) =>
      paths.retainWhere((p) => entries.any((e) => e.path == p));

  bool selectRange(List<FileEntry> visible, FileEntry entry) {
    final a = visible.indexWhere((e) => e.path == anchor);
    final b = visible.indexOf(entry);
    if (a < 0 || b < 0) return false;
    paths
      ..clear()
      ..addAll(
        visible.sublist(a < b ? a : b, (a < b ? b : a) + 1).map((e) => e.path),
      );
    return true;
  }
}
