import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// Presentation context only; never an authorization or data-source decision.
class AppPreviewScope extends InheritedWidget {
  const AppPreviewScope({super.key, required this.clock, required super.child});
  final DateTime clock;
  static AppPreviewScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppPreviewScope>();
  @override
  bool updateShouldNotify(AppPreviewScope oldWidget) =>
      clock != oldWidget.clock;
}

class AppPreviewBadge extends StatelessWidget {
  const AppPreviewBadge({super.key});
  @override
  Widget build(BuildContext context) => AppPreviewScope.maybeOf(context) == null
      ? const SizedBox.shrink()
      : Semantics(
          label: 'Dữ liệu mẫu, chỉ dùng để xem thử',
          child: ExcludeSemantics(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(AppRadius.field)),
            child: const Text('Mẫu', style: AppTextStyles.captionStrong),
          )),
        );
}
