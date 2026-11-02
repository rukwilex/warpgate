import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:window_manager/window_manager.dart';

enum WindowChrome {
  native,
  mac,
  windows;

  static WindowChrome get forPlatform {
    if (kIsWeb) return native;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => mac,
      TargetPlatform.windows => windows,
      _ => native,
    };
  }

  bool get custom => this != native;
}

final windowChromeProvider = Provider<WindowChrome>(
  (ref) => WindowChrome.forPlatform,
);

@immutable
class WindowFrame {
  const new({
    this.focused = true,
    this.maximized = false,
    this.fullScreen = false,
  });

  final bool focused;
  final bool maximized;
  final bool fullScreen;

  WindowFrame copyWith({bool? focused, bool? maximized, bool? fullScreen}) =>
      WindowFrame(
        focused: focused ?? this.focused,
        maximized: maximized ?? this.maximized,
        fullScreen: fullScreen ?? this.fullScreen,
      );

  @override
  bool operator ==(Object other) =>
      other is WindowFrame &&
      other.focused == focused &&
      other.maximized == maximized &&
      other.fullScreen == fullScreen;

  @override
  int get hashCode => Object.hash(focused, maximized, fullScreen);
}

final windowFrameProvider =
    NotifierProvider<WindowFrameController, WindowFrame>(
      WindowFrameController.new,
    );

class WindowFrameController extends Notifier<WindowFrame> with WindowListener {
  @override
  WindowFrame build() {
    if (!ref.watch(windowChromeProvider).custom) return const WindowFrame();
    windowManager.addListener(this);
    ref.onDispose(() => windowManager.removeListener(this));
    unawaited(_sync());
    return const WindowFrame();
  }

  Future<void> _sync() async {
    final (focused, maximized, fullScreen) = await (
      windowManager.isFocused(),
      windowManager.isMaximized(),
      windowManager.isFullScreen(),
    ).wait;
    if (!ref.mounted) return;
    state = WindowFrame(
      focused: focused,
      maximized: maximized,
      fullScreen: fullScreen,
    );
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (ref.mounted) state = state.copyWith(maximized: maximized);
  }

  @override
  void onWindowFocus() => state = state.copyWith(focused: true);

  @override
  void onWindowBlur() => state = state.copyWith(focused: false);

  @override
  void onWindowMaximize() => state = state.copyWith(maximized: true);

  @override
  void onWindowUnmaximize() => state = state.copyWith(maximized: false);

  @override
  void onWindowRestore() => unawaited(_syncMaximized());

  @override
  void onWindowResized() => unawaited(_syncMaximized());

  @override
  void onWindowEnterFullScreen() => state = state.copyWith(fullScreen: true);

  @override
  void onWindowLeaveFullScreen() => state = state.copyWith(fullScreen: false);
}

final windowControlsProvider = Provider<WindowControls>(
  (ref) => const WindowControls(),
);

class WindowControls {
  const new();

  static const _mac = MethodChannel('warpgate/window');

  Future<void> startDragging() => windowManager.startDragging();

  Future<void> minimize() => windowManager.minimize();

  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> close() => windowManager.close();

  Future<void> showSystemMenu() => windowManager.popUpWindowMenu();

  Future<void> titleBarDoubleClick(WindowChrome chrome) async {
    if (chrome == WindowChrome.mac) {
      await _mac.invokeMethod<void>('titleBarDoubleClick');
    } else {
      await toggleMaximize();
    }
  }

  Future<void> matchTheme(
    WindowChrome chrome, {
    required Color background,
    required Brightness brightness,
    required double titleBarHeight,
  }) async {
    await windowManager.setBackgroundColor(background);
    await windowManager.setBrightness(brightness);
    if (chrome == WindowChrome.mac) {
      await _mac.invokeMethod<void>('setTitleBarHeight', titleBarHeight);
    }
  }
}

class WindowChromeEffects extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WindowChromeEffects> createState() =>
      _WindowChromeEffectsState();
}

class _WindowChromeEffectsState extends ConsumerState<WindowChromeEffects> {
  (Color, Brightness, double)? _applied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chrome = ref.read(windowChromeProvider);
    if (!chrome.custom) return;
    final wanted = (
      context.colors.canvasDeep,
      Theme.of(context).brightness,
      context.sizes.titleBar,
    );
    if (wanted == _applied) return;
    _applied = wanted;
    unawaited(
      ref
          .read(windowControlsProvider)
          .matchTheme(
            chrome,
            background: wanted.$1,
            brightness: wanted.$2,
            titleBarHeight: wanted.$3,
          ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
