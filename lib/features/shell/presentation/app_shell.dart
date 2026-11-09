import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/palette_overlay.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/shell_destinations.dart';
import 'package:warpgate/features/shell/presentation/shell_layout.dart';
import 'package:warpgate/features/shell/presentation/title_bar.dart';
import 'package:warpgate/features/shell/presentation/widgets/shell_phone_status.dart';
import 'package:warpgate/features/shell/presentation/widgets/shell_sidebar.dart';
import 'package:warpgate/features/shell/presentation/widgets/status_bar.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/shell/utils/shell_section.dart';

class AppShell extends ConsumerWidget {
  const new({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = shellLayoutOf(context);
    final collapsed = ref.watch(
      settingsProvider.select((s) => s.sidebarCollapsed),
    );
    final colors = context.colors;
    final content = PaletteOverlay(child: child);
    if (layout == ShellLayout.phone) {
      final index = shellPhoneDestinations
          .indexWhere((d) => d.route == shellSection(location))
          .clamp(0, shellPhoneDestinations.length - 1);
      return Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: content),
              const ShellPhoneStatus(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          backgroundColor: colors.canvasDeep,
          indicatorColor: colors.pressed,
          surfaceTintColor: colors.transparent,
          height: context.sizes.touchTarget + context.space.lg,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) =>
              GoRouter.of(context).go(shellPhoneDestinations[value].route),
          destinations: [
            for (final destination in shellPhoneDestinations)
              NavigationDestination(
                icon: Icon(
                  destination.icon,
                  size: context.sizes.icon,
                  color: colors.textSecondary,
                ),
                selectedIcon: Icon(
                  destination.icon,
                  size: context.sizes.icon,
                  color: colors.textPrimary,
                ),
                label: destination.label,
              ),
          ],
        ),
      );
    }
    final rail = layout == ShellLayout.tablet || collapsed;
    final titleBar = ref.watch(windowChromeProvider).custom;
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellSidebar(location: location, rail: rail, paletteButton: !titleBar),
        const WgHairline(vertical: true),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (titleBar) const WgHairline(),
              Expanded(child: content),
              const StatusBar(),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: colors.canvas,
      body: titleBar
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TitleBar(onWorkbench: location == Routes.workbench),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}
