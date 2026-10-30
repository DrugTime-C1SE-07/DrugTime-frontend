import 'package:flutter/widgets.dart';
import '../../data/capture_services.dart';

class CaptureScope extends InheritedWidget {
  const CaptureScope({super.key, required this.services, required super.child});
  final CaptureServices services;
  static CaptureServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CaptureScope>()!.services;
  static CaptureServices? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CaptureScope>()?.services;
  @override
  bool updateShouldNotify(CaptureScope oldWidget) =>
      services != oldWidget.services;
}
