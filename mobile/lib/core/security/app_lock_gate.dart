import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'app_lock_controller.dart';
import 'app_lock_screen.dart';

/// Cho màn Cài đặt đọc và đổi "Khóa ứng dụng".
class AppLockScope extends InheritedNotifier<AppLockController> {
  const AppLockScope({
    super.key,
    required AppLockController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLockController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.notifier;
}

/// Phủ màn khóa hoặc lớp che lên toàn bộ app (gồm cả dialog, bottom sheet).
class AppLockGate extends StatelessWidget {
  const AppLockGate({
    super.key,
    required this.controller,
    required this.topRoute,
    required this.onSignOut,
    required this.child,
    this.exemptRoutes = const {},
  });

  final AppLockController controller;
  final ValueListenable<String?> topRoute;
  final Future<void> Function() onSignOut;

  /// Route không bị khóa (màn nhắc liều trên màn hình khóa, Q2).
  final Set<String> exemptRoutes;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppLockScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, topRoute]),
          builder: (context, _) {
            final exempt = exemptRoutes.contains(topRoute.value);
            final showLock = controller.locked && !exempt;
            final showCover = !showLock && !exempt && controller.obscured;
            final hidden = showLock || showCover;
            return Stack(fit: StackFit.expand, children: [
              ExcludeSemantics(
                excluding: hidden,
                child: AbsorbPointer(absorbing: hidden, child: child),
              ),
              if (showCover) const AppPrivacyCover(),
              if (showLock)
                AppLockScreen(
                  onUnlock: controller.unlock,
                  onSignOut: onSignOut,
                  // Đọc lại lúc tự gọi prompt: route có thể vừa đổi trong frame này.
                  canAutoPrompt: () => !exemptRoutes.contains(topRoute.value),
                ),
            ]);
          },
        ),
      );
}

/// Che nội dung khi app rời foreground, để ảnh trong màn đa nhiệm không lộ dữ liệu.
class AppPrivacyCover extends StatelessWidget {
  const AppPrivacyCover({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
        key: Key('app-privacy-cover'),
        color: AppColors.brandStrong,
        child: Center(
          child: Icon(Icons.lock_outline, size: 48, color: AppColors.onBrand),
        ),
      );
}
