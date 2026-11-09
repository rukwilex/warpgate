import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/shell/presentation/window_chrome.dart';
import 'package:warpgate/features/workspace/presentation/widgets/session_tabs.dart';

class TitleBar extends ConsumerWidget {
  const new({required this.onWorkbench, super.key});

  final bool onWorkbench;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(windowChromeProvider);
    final frame = ref.watch(windowFrameProvider);
    final keys = ref.watch(shortcutMapProvider);
    final sizes = context.sizes;
    final space = context.space;
    final inset = chrome == WindowChrome.mac && !frame.fullScreen;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Title bar',
      child: Container(
        key: const ValueKey('title-bar'),
        height: sizes.titleBar,
        color: context.colors.canvasDeep,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: WindowDragArea()),
            WindowFocusFade(
              child: Row(
                children: [
                  AnimatedContainer(
                    key: const ValueKey('title-bar-inset'),
                    duration: context.motion.medium,
                    curve: context.motion.curve,
                    width: inset ? sizes.trafficLights : space.sm,
                  ),
                  Expanded(
                    child: SessionTabs(
                      embedded: true,
                      onWorkbench: onWorkbench,
                    ),
                  ),
                  SizedBox(width: space.sm),
                  WgIconButton(
                    icon: WgIcons.search,
                    label: 'Command palette',
                    compact: true,
                    shortcut: keys['palette.open'],
                    onPressed: () =>
                        ref.read(commandRegistryProvider).run('palette.open'),
                  ),
                  if (chrome == WindowChrome.windows)
                    const ExcludeSemantics(
                      child: Visibility(
                        visible: false,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: WindowCaptionButtons(),
                      ),
                    )
                  else
                    SizedBox(width: space.sm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowDragArea extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(windowChromeProvider);
    final controls = ref.watch(windowControlsProvider);
    return GestureDetector(
      key: const ValueKey('window-drag-area'),
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onPanStart: (_) => unawaited(controls.startDragging()),
      onDoubleTap: () => unawaited(controls.titleBarDoubleClick(chrome)),
      onSecondaryTapUp: chrome == WindowChrome.windows
          ? (_) => unawaited(controls.showSystemMenu())
          : null,
      child: const SizedBox.expand(),
    );
  }
}

class WindowFocusFade extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(windowFrameProvider.select((f) => f.focused));
    final theme = Theme.of(context);
    return AnimatedTheme(
      duration: context.motion.fast,
      curve: context.motion.curve,
      data: focused
          ? theme
          : theme.copyWith(
              extensions: [
                for (final extension in theme.extensions.values)
                  if (extension is WgColors)
                    extension.inactive()
                  else
                    extension,
              ],
            ),
      child: child,
    );
  }
}

class WindowCaptionButtons extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maximized = ref.watch(windowFrameProvider.select((f) => f.maximized));
    final controls = ref.watch(windowControlsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WgCaptionButton(
          glyph: WgCaptionGlyph.minimize,
          label: 'Minimize',
          onPressed: () => unawaited(controls.minimize()),
        ),
        WgCaptionButton(
          glyph: maximized ? WgCaptionGlyph.restore : WgCaptionGlyph.maximize,
          label: maximized ? 'Restore' : 'Maximize',
          onPressed: () => unawaited(controls.toggleMaximize()),
        ),
        WgCaptionButton(
          glyph: WgCaptionGlyph.close,
          label: 'Close',
          onPressed: () => unawaited(controls.close()),
        ),
      ],
    );
  }
}

class WindowCaptionLayer extends ConsumerWidget {
  const new({required this.locked, required this.child, super.key});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(windowChromeProvider);
    if (!chrome.custom) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (locked)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: context.sizes.titleBar,
            child: const WindowDragArea(),
          ),
        if (chrome == WindowChrome.windows)
          const Positioned(
            top: 0,
            right: 0,
            child: WindowFocusFade(child: WindowCaptionButtons()),
          ),
      ],
    );
  }
}
