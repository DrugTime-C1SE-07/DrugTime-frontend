import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tên route đang ở trên cùng của Navigator, để gate biết màn nào đang hiện.
class TopRouteObserver extends NavigatorObserver {
  final TopRouteName topRoute = TopRouteName();

  void _set(Route<dynamic>? route) => topRoute._set(route?.settings.name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (topRoute.value == route.settings.name) _set(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null && topRoute.value == oldRoute.settings.name) {
      _set(newRoute);
    }
  }
}

class TopRouteName extends ChangeNotifier implements ValueListenable<String?> {
  String? _value;

  /// Luôn đúng ngay khi Navigator đổi route, kể cả trước khi listener được báo.
  @override
  String? get value => _value;

  void _set(String? name) {
    if (name == _value) return;
    _value = name;
    // Navigator đẩy route trong lúc build; gate là cha của Navigator nên chỉ
    // được rebuild ở frame sau.
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}
