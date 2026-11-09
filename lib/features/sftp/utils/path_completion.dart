import 'package:path/path.dart' as p;

abstract final class PathCompletion {
  static (String, String) split(String input, p.Context paths) {
    final separator = paths.separator;
    final index = input.lastIndexOf(separator);
    if (index < 0) return ('', input);
    final directory = index == 0 ? separator : input.substring(0, index);
    return (directory, input.substring(index + 1));
  }

  static List<String> matches(Iterable<String> names, String prefix) {
    final lower = prefix.toLowerCase();
    final exact = [
      for (final name in names)
        if (name.startsWith(prefix)) name,
    ];
    if (exact.isNotEmpty || prefix.isEmpty) return exact..sort();
    return [
      for (final name in names)
        if (name.toLowerCase().startsWith(lower)) name,
    ]..sort();
  }

  static String commonPrefix(List<String> names) {
    if (names.isEmpty) return '';
    var prefix = names.first;
    for (final name in names.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < name.length && prefix[i] == name[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
    }
    return prefix;
  }

  static String? complete(String input, List<String> folders, p.Context paths) {
    final (directory, prefix) = split(input, paths);
    final found = matches(folders, prefix);
    if (found.isEmpty) return null;
    final base = directory == paths.separator
        ? paths.separator
        : directory.isEmpty
        ? ''
        : '$directory${paths.separator}';
    if (found.length == 1) return '$base${found.single}${paths.separator}';
    final common = commonPrefix(found);
    if (common.length <= prefix.length) return null;
    return '$base$common';
  }
}
