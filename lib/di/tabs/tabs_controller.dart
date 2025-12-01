import 'package:flutter/foundation.dart';

enum AppTab {
  dashboard,
  tunnels,
  settings,
  console
}

class TabsController extends ChangeNotifier {
  AppTab _current = AppTab.settings; // по умолчанию настройки, можно поменять

  AppTab get current => _current;

  void selectTab(AppTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}
