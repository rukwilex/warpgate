String folderTitle(String path) {
  final name = path.split('/').where((part) => part.isNotEmpty);
  return name.isEmpty ? path : name.last;
}
