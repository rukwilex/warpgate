import 'package:meta/meta.dart';

enum LinkState { idle, connecting, connected, busy, reconnecting, dropped }

@immutable
class LinkStatus {
  const new(this.state, {this.message, this.attempt = 0, this.nextRetry});

  static const idle = LinkStatus(LinkState.idle);

  final LinkState state;
  final String? message;
  final int attempt;
  final DateTime? nextRetry;

  bool get isUsable => state == LinkState.connected || state == LinkState.busy;

  @override
  bool operator ==(Object other) =>
      other is LinkStatus &&
      other.state == state &&
      other.message == message &&
      other.attempt == attempt &&
      other.nextRetry == nextRetry;

  @override
  int get hashCode => Object.hash(state, message, attempt, nextRetry);
}

@immutable
class ExecResult {
  const new({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.duration,
    this.timedOut = false,
    this.error,
  });

  factory failure(String error, Duration duration) => ExecResult(
    stdout: '',
    stderr: '',
    exitCode: null,
    duration: duration,
    error: error,
  );

  final String stdout;
  final String stderr;
  final int? exitCode;
  final Duration duration;
  final bool timedOut;
  final String? error;

  bool get succeeded => error == null && !timedOut && exitCode == 0;
}

abstract final class Backoff {
  static const _steps = [1, 2, 4, 8, 15, 30];

  static const maxAttempts = 10;

  static Duration delay(int attempt) =>
      Duration(seconds: _steps[attempt.clamp(0, _steps.length - 1)]);
}
