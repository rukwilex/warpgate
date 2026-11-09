import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/diagnostics/app_health.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/shortcuts/shortcut_codec.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/cli/presentation/cli_bridge.dart';
import 'package:warpgate/features/connection/presentation/connection_providers.dart';
import 'package:warpgate/features/hosts/presentation/hosts_controller.dart';
import 'package:warpgate/features/mcp/presentation/mcp_service.dart';
import 'package:warpgate/features/palette/presentation/command_registry.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate/features/shell/presentation/ui_state.dart';
import 'package:warpgate/features/terminal/presentation/terminal_sessions.dart';
import 'package:warpgate/features/workspace/presentation/workbench_controller.dart';
import 'package:warpgate_core/core/diagnostics/watchdog.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:window_manager/window_manager.dart';

class AppEffects extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppEffects> createState() => _AppEffectsState();
}

class _AppEffectsState extends ConsumerState<AppEffects> {
  late final AppLifecycleListener _lifecycle;
  late final AppHealth _health;
  final Set<String> _connected = {};

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _lifecycle = AppLifecycleListener(
      onResume: _wake,
      onShow: _wake,
      onPause: () => unawaited(_persist()),
      onHide: () => unawaited(_persist()),
      onDetach: () => unawaited(_persist()),
      onExitRequested: () async {
        await _persist();
        return AppExitResponse.exit;
      },
    );
    ref
      ..read(mcpServerProvider)
      ..read(cliBridgeProvider);
    _health = ref.read(appHealthProvider);
    _health.stallNotice.addListener(_showStall);
    unawaited(_health.start());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_restore()));
  }

  void _wake() => unawaited(ref.read(connectionPoolProvider).probeAll());

  void _showStall() {
    final stall = _health.stallNotice.value;
    final context = rootNavigatorKey.currentContext;
    if (stall == null || context == null || !context.mounted) return;
    final seconds = (stall.duration.inMilliseconds / 1000).toStringAsFixed(1);
    showWgToast(
      context,
      stall.activity == Activity.idle
          ? 'Warpgate was not responding for $seconds s. Details are in Settings, Diagnostics'
          : 'Warpgate was not responding for $seconds s (${stall.activity.label.toLowerCase()}). Details are in Settings, Diagnostics',
    );
  }

  Future<void> _restore() async {
    final sessions = ref.read(terminalSessionsProvider);
    await sessions.preloadScrollback();
    await ref.read(hostsProvider.future);
    await sessions.restoreAll(ref.read(workbenchProvider));
  }

  Future<void> _persist() async {
    await ref.read(workbenchProvider.notifier).flush();
    await ref.read(terminalSessionsProvider).persistScrollback();
  }

  bool _onKey(KeyEvent event) {
    if (ref.read(shortcutsSuspendedProvider) > 0 || ref.read(appLockProvider)) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    ref.read(appLockProvider.notifier).touch();
    final navigator = rootNavigatorKey.currentState;
    final dialogOpen = navigator?.canPop() ?? false;
    final keys = ref.read(shortcutMapProvider);
    for (final MapEntry(key: id, value: activator) in keys.entries) {
      if (!ShortcutCodec.matches(activator, event)) continue;
      if (dialogOpen && id != 'palette.open') return false;
      ref.read(commandRegistryProvider).run(id);
      return true;
    }
    return false;
  }

  void _syncTitle() {
    if (!PlatformInfo.isDesktop) return;
    final bench = ref.read(workbenchProvider);
    final name = bench.activeWorkspace?.name;
    unawaited(
      windowManager.setTitle(name == null ? 'Warpgate' : 'Warpgate — $name'),
    );
  }

  @override
  void dispose() {
    _health.stallNotice.removeListener(_showStall);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _forget(String hostId) async {
    _connected.remove(hostId);
    await ref.read(portForwarderProvider).stopHost(hostId);
    await ref.read(connectionPoolProvider).disconnect(hostId);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(settingsProvider.select((s) => s.sshEngine), (_, engine) {
        NativeEngine.preferred = engine == 'dart'
            ? SshEngineKind.dart
            : SshEngineKind.native;
      })
      ..listen(
        workbenchProvider.select((state) => state.activeWorkspace?.name),
        (_, _) => _syncTitle(),
      )
      ..listen(hostsProvider, (previous, next) {
        final before = previous?.value?.byId.keys ?? const <String>[];
        final after = next.value?.byId ?? const <String, Host>{};
        for (final hostId in before.where((id) => !after.containsKey(id))) {
          unawaited(_forget(hostId));
        }
      })
      ..listen(hostLinksProvider, (_, links) {
        final catalog = ref.read(hostsProvider).value;
        final forwarder = ref.read(portForwarderProvider);
        for (final MapEntry(key: hostId, value: link) in links.entries) {
          if (link.isUsable && _connected.add(hostId)) {
            for (final spec
                in catalog?.host(hostId)?.forwards ??
                    const <PortForwardSpec>[]) {
              if (spec.autoStart) unawaited(forwarder.start(hostId, spec));
            }
          } else if (!link.isUsable) {
            _connected.remove(hostId);
          }
        }
      });
    return Listener(
      onPointerDown: (_) => ref.read(appLockProvider.notifier).touch(),
      child: widget.child,
    );
  }
}
