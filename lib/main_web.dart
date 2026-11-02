import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/shell/presentation/web_unsupported.dart';

void main() => runApp(
  MaterialApp(
    title: 'Warpgate',
    debugShowCheckedModeBanner: false,
    theme: WgTheme.build(brightness: Brightness.light),
    darkTheme: WgTheme.build(brightness: Brightness.dark),
    home: const WebUnsupportedScreen(),
  ),
);
