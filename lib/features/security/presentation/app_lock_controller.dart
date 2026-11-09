import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:warpgate/core/data/storage_providers.dart';
import 'package:warpgate/core/platform/platform_info.dart';
import 'package:warpgate/features/settings/presentation/settings_controller.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/security/data/pin_hasher.dart';

final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);

class AppLockController extends Notifier<bool> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  Timer? _idle;

  @override
  bool build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _idle?.cancel();
    });
    final locked = ref.read(settingsProvider).appLock;
    if (!locked) touch();
    return locked;
  }

  Duration get _timeout =>
      Duration(minutes: ref.read(settingsProvider).autoLockMinutes);

  bool get _enabled => ref.read(settingsProvider).appLock;

  void touch() {
    _idle?.cancel();
    if (!_enabled || _timeout == Duration.zero) return;
    _idle = Timer(_timeout, lock);
  }

  void lock() {
    if (_enabled) state = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && DateTime.now().difference(since) >= _timeout) {
          lock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> setPin(String pin) async {
    final hash = await PinHasher.hash(pin);
    await ref.read(secretStoreProvider).write(SecretKeys.appPin, hash);
  }

  Future<void> clearPin() =>
      ref.read(secretStoreProvider).delete(SecretKeys.appPin);

  Future<bool> unlockWithPin(String pin) async {
    final stored = await ref.read(secretStoreProvider).read(SecretKeys.appPin);
    if (stored == null || !await PinHasher.verify(pin, stored)) return false;
    _unlock();
    return true;
  }

  Future<bool> canUseBiometrics() async {
    if (PlatformInfo.isWeb || !ref.read(settingsProvider).biometricUnlock) {
      return false;
    }
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Warpgate',
      );
      if (ok) _unlock();
      return ok;
    } on Object {
      return false;
    }
  }

  void _unlock() {
    state = false;
    touch();
  }
}
