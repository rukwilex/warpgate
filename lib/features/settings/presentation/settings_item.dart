import 'package:flutter/widgets.dart';

class SettingsItem {
  const new(
    this.title,
    this.control, {
    this.description,
    this.keywords = '',
    this.stacked = false,
    this.leading,
  });

  final String title;
  final Widget? leading;
  final String? description;
  final Widget control;
  final String keywords;
  final bool stacked;

  bool matches(String query) => '$title ${description ?? ''} $keywords'
      .toLowerCase()
      .contains(query.toLowerCase());
}
