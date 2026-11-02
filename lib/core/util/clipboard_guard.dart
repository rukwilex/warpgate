import 'dart:async';

import 'package:flutter/services.dart';

abstract final class ClipboardGuard {
  static Timer? _timer;

  static Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  static Future<void> copySecret(
    String secret, {
    required Duration clearAfter,
  }) async {
    await Clipboard.setData(ClipboardData(text: secret));
    _timer?.cancel();
    if (clearAfter <= Duration.zero) return;
    _timer = Timer(clearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == secret) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}
