import 'package:flutter/foundation.dart';

class PathBarController extends ChangeNotifier {
  bool _editRequested = false;

  void edit() {
    _editRequested = true;
    notifyListeners();
  }

  bool takeEditRequest() {
    final value = _editRequested;
    _editRequested = false;
    return value;
  }
}
