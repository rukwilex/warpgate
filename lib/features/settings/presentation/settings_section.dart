import 'package:flutter/widgets.dart';
import 'package:warpgate/features/settings/presentation/settings_item.dart';

class SettingsSection {
  const new(this.id, this.title, this.icon, this.items);

  final String id;
  final String title;
  final IconData icon;
  final List<SettingsItem> items;
}
