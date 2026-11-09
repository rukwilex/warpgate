enum ExitKind {
  ok(0, 'Success'),
  general(1, 'General error'),
  usage(2, 'Usage error'),
  notFound(3, 'Not found'),
  auth(4, 'Authentication failed'),
  hostKey(5, 'Host key mismatch or not trusted'),
  connection(6, 'Connection failed'),
  partial(7, 'Partial failure on a multi-host command'),
  interrupted(130, 'Interrupted');

  new(this.code, this.meaning);

  final int code;
  final String meaning;
}

class ActionFailure implements Exception {
  const new(this.message, {this.kind = ExitKind.general, this.hint});

  final String message;
  final ExitKind kind;
  final String? hint;

  @override
  String toString() => message;
}
