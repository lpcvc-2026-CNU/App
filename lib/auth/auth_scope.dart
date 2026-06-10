import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// [AuthController] 를 위젯 트리에 제공하는 InheritedNotifier.
///
/// 하위 위젯에서 `AuthScope.of(context)` 로 컨트롤러에 접근하고,
/// 컨트롤러가 notifyListeners() 하면 구독 위젯이 자동 리빌드된다.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 가장 가까운 AuthScope 의 컨트롤러를 반환(리빌드 구독).
  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope 가 위젯 트리에 없습니다.');
    return scope!.notifier!;
  }

  /// 리빌드 구독 없이 컨트롤러만 읽을 때 사용(이벤트 핸들러 등).
  static AuthController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope 가 위젯 트리에 없습니다.');
    return scope!.notifier!;
  }
}
