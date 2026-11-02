import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/app/app_effects.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/security/presentation/lock_screen.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/interaction_host.dart';
import 'package:warpgate/features/shell/presentation/native_menus.dart';
import 'package:warpgate/features/shell/presentation/title_bar.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';

class WarpgateApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    ThemeData theme(Brightness brightness) => WgTheme.build(
      brightness: brightness,
      accent: settings.accent,
      density: settings.density,
      touch: PlatformInfo.isMobile,
      reduceMotion: reduceMotion,
    );
    return MaterialApp.router(
      title: 'Warpgate',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: settings.themeMode,
      builder: (context, child) => AppEffects(
        child: WindowChromeEffects(
          child: NativeMenus(
            child: InteractionHost(
              child: Consumer(
                builder: (context, ref, _) {
                  final locked = ref.watch(appLockProvider);
                  return WindowCaptionLayer(
                    locked: locked,
                    child: Stack(
                      children: [
                        ExcludeSemantics(
                          excluding: locked,
                          child: child ?? const SizedBox.shrink(),
                        ),
                        if (locked)
                          Positioned.fill(
                            child: Overlay(
                              initialEntries: [
                                OverlayEntry(
                                  builder: (_) => const LockScreen(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
