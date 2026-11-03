import 'dart:async';

sealed class InteractionRequest<T> {
  new();

  final Completer<T> _completer = Completer<T>();

  T get fallback;

  Future<T> get answer => _completer.future;

  bool get isAnswered => _completer.isCompleted;

  void respond(T value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void dismiss() => respond(fallback);
}

enum HostKeyVerdict { trustOnce, trustAndSave, reject }

class HostKeyRequest extends InteractionRequest<HostKeyVerdict> {
  new({
    required this.hostLabel,
    required this.endpoint,
    required this.keyType,
    required this.fingerprint,
    this.previousFingerprint,
  });

  final String hostLabel;
  final String endpoint;
  final String keyType;
  final String fingerprint;
  final String? previousFingerprint;

  bool get changed => previousFingerprint != null;

  @override
  HostKeyVerdict get fallback => HostKeyVerdict.reject;
}

class SecretRequest extends InteractionRequest<String?> {
  new({
    required this.title,
    required this.message,
    required this.fieldLabel,
    this.allowRemember = false,
  });

  final String title;
  final String message;
  final String fieldLabel;
  final bool allowRemember;
  bool remember = false;

  @override
  String? get fallback => null;
}

enum ConflictResolution { overwrite, skip, rename, resume }

typedef ConflictAnswer = ({ConflictResolution resolution, bool applyToAll});

class ConflictRequest extends InteractionRequest<ConflictAnswer> {
  new({
    required this.path,
    required this.targetLabel,
    required this.existingSize,
    required this.incomingSize,
  });

  final String path;
  final String targetLabel;
  final int existingSize;
  final int incomingSize;

  @override
  ConflictAnswer get fallback =>
      (resolution: ConflictResolution.skip, applyToAll: false);
}

class ApprovalRequest extends InteractionRequest<bool> {
  new({
    required this.source,
    required this.action,
    required this.target,
    required this.detail,
  });

  final String source;
  final String action;
  final String target;
  final String detail;

  @override
  bool get fallback => false;
}

class InteractionBroker {
  final _controller = StreamController<InteractionRequest<Object?>>.broadcast();
  final List<InteractionRequest<Object?>> _pending = [];
  int _listeners = 0;

  Stream<InteractionRequest<Object?>> get requests => _controller.stream;

  List<InteractionRequest<Object?>> get pending => List.unmodifiable(_pending);

  void attach() => _listeners++;

  void detach() => _listeners = (_listeners - 1).clamp(0, 1 << 30);

  Future<T> ask<T>(InteractionRequest<T> request) {
    if (_listeners == 0) {
      request.dismiss();
      return request.answer;
    }
    _pending.add(request);
    _controller.add(request);
    return request.answer.whenComplete(() => _pending.remove(request));
  }

  void dispose() {
    for (final request in List.of(_pending)) {
      request.dismiss();
    }
    unawaited(_controller.close());
  }
}
