import '../frb_generated.dart';
import 'error.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

String engineVersion() =>
    WarpgateEngine.instance.api.crateApiUtilEngineVersion();

Future<String> sha256File({required String path}) =>
    WarpgateEngine.instance.api.crateApiUtilSha256File(path: path);

abstract class CancelToken implements RustOpaqueInterface {
  void cancel();

  bool isCancelled();

  factory CancelToken() =>
      WarpgateEngine.instance.api.crateApiUtilCancelTokenNew();
}
