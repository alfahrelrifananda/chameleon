import 'package:flutter/material.dart';

class ScrollNotifier extends ChangeNotifier {
  bool _isVisible = true;

  bool get isVisible => _isVisible;

  void setVisible(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }
}