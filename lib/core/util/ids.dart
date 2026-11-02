import 'package:uuid/uuid.dart';

abstract final class Ids {
  static const _uuid = Uuid();

  static String next() => _uuid.v4();

  static String short() => _uuid.v4().substring(0, 8);
}
