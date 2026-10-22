import 'package:flutter/widgets.dart';
import 'family_alert_controller.dart';

// Dùng chung controller cho inbox/detail/badge; of theo dõi state, read chỉ lấy để gọi.
class FamilyAlertScope extends InheritedNotifier<FamilyAlertController> {
  const FamilyAlertScope(
      {super.key,
      required FamilyAlertController controller,
      required super.child})
      : super(notifier: controller);
  static FamilyAlertController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FamilyAlertScope>()!.notifier!;
  static FamilyAlertController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FamilyAlertScope>()?.notifier;
  static FamilyAlertController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FamilyAlertScope>()!.notifier!;
}
