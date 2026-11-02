import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/security/presentation/app_lock_controller.dart';

class LockScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _biometrics = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_tryBiometrics());
  }

  Future<void> _tryBiometrics() async {
    final lock = ref.read(appLockProvider.notifier);
    final available = await lock.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometrics = available);
    if (available) await lock.unlockWithBiometrics();
  }

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await ref
        .read(appLockProvider.notifier)
        .unlockWithPin(_pin.text);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (!ok) {
        _error = 'Wrong PIN';
        _pin.clear();
      }
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvasDeep,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.space.xxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sizes.lockPanel),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  WgIcons.lock,
                  size: context.sizes.iconLarge,
                  color: context.colors.textMuted,
                ),
                SizedBox(height: context.space.lg),
                Semantics(
                  header: true,
                  child: Text(
                    'Warpgate is locked',
                    textAlign: TextAlign.center,
                    style: context.type.title,
                  ),
                ),
                SizedBox(height: context.space.xs),
                Text(
                  'Sessions and transfers keep running.',
                  textAlign: TextAlign.center,
                  style: context.type.caption,
                ),
                SizedBox(height: context.space.xl),
                WgTextField(
                  controller: _pin,
                  label: 'PIN',
                  obscure: true,
                  autofocus: true,
                  error: _error,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => unawaited(_submit()),
                ),
                SizedBox(height: context.space.md),
                WgButton.primary(
                  label: 'Unlock',
                  expand: true,
                  loading: _checking,
                  onPressed: () => unawaited(_submit()),
                ),
                if (_biometrics) ...[
                  SizedBox(height: context.space.sm),
                  WgButton.ghost(
                    label: 'Use biometrics',
                    icon: WgIcons.fingerprint,
                    expand: true,
                    onPressed: () => unawaited(
                      ref.read(appLockProvider.notifier).unlockWithBiometrics(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
