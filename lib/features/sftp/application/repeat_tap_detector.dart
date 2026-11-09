import 'package:flutter/gestures.dart';

class RepeatTapDetector {
  String? _lastPath;
  DateTime _lastAt = DateTime(0);

  bool repeats(String path, {required DateTime now, required bool modified}) {
    final repeat =
        _lastPath == path &&
        now.difference(_lastAt) <= kDoubleTapTimeout &&
        !modified;
    _lastPath = repeat ? null : path;
    _lastAt = now;
    return repeat;
  }
}
