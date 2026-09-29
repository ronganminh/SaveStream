import 'package:flutter/widgets.dart';

class AppLifecycleController extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycleState? _state;

  AppLifecycleState? get state => _state;

  void start() {
    _state = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
