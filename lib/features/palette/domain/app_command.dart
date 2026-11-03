import 'package:flutter/widgets.dart';
import 'package:warpgate_core/actions/action_spec.dart';

export 'package:warpgate_core/actions/action_spec.dart' show CommandCategory;

@immutable
class AppCommand {
  const new({
    required this.id,
    required this.title,
    required this.category,
    required this.run,
    this.shortcut,
    this.icon,
    this.keywords = const [],
    this.rebindable = true,
  });

  final String id;
  final String title;
  final CommandCategory category;
  final VoidCallback run;
  final SingleActivator? shortcut;
  final IconData? icon;
  final List<String> keywords;
  final bool rebindable;

  AppCommand withShortcut(SingleActivator? value) => AppCommand(
    id: id,
    title: title,
    category: category,
    run: run,
    shortcut: value,
    icon: icon,
    keywords: keywords,
    rebindable: rebindable,
  );

  int score(String query) {
    if (query.isEmpty) return 1;
    final q = query.toLowerCase();
    final haystack =
        '${title.toLowerCase()} ${keywords.join(' ').toLowerCase()} ${category.label.toLowerCase()}';
    if (title.toLowerCase().startsWith(q)) return 100;
    if (haystack.contains(q)) return 60;
    var index = 0;
    for (final char in q.split('')) {
      index = haystack.indexOf(char, index);
      if (index < 0) return 0;
      index++;
    }
    return 20;
  }
}
