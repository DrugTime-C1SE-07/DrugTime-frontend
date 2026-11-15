import 'dart:async';
import 'package:drugtime_mobile/features/home/presentation/home_screen.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/profile_failure.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../profile/profile_test_helpers.dart';

void main() {
  Future<void> showHome(
      WidgetTester tester, ProfileController controller) async {
    await tester.pumpWidget(ProfileScope(
        controller: controller,
        child: MaterialApp(
            home: Scaffold(
                body: HomeScreen(
                    active: true, onFamily: () {}, onSchedule: () {})))));
    await tester.pump();
  }

  testWidgets('skeleton transitions to real name and empty schedule',
      (tester) async {
    final repo = FakeProfileRepository()
      ..pendingRead = Completer<HealthProfile>();
    final controller = ProfileController(repo);
    addTearDown(controller.dispose);
    await showHome(tester, controller);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.label == 'Đang tải trang chủ'),
        findsOneWidget);
    repo.pendingRead!.complete(const HealthProfile(fullName: 'Tên thật'));
    await tester.pumpAndSettle();
    expect(find.text('Tên thật'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.label == 'Đang tải trang chủ'),
        findsNothing);
    expect(find.text('Losartan'), findsNothing);
    expect(find.text('1/4 liều'), findsNothing);
    expect(find.byType(Image), findsWidgets);
    final orange = find.byWidgetPredicate((widget) =>
        widget is ColoredBox && widget.color == const Color(0xFFFFAC56));
    expect(orange, findsOneWidget);
    expect(tester.getSize(orange).height, greaterThan(0));
  });

  testWidgets('network error ends loading and retry loads name',
      (tester) async {
    final repo = FakeProfileRepository()
      ..fetchFailure = const ProfileFailure(ProfileFailureKind.network);
    final controller = ProfileController(repo);
    addTearDown(controller.dispose);
    await showHome(tester, controller);
    await tester.pumpAndSettle();
    expect(find.text('Không thể kết nối. Vui lòng thử lại.'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.label == 'Đang tải trang chủ'),
        findsNothing);
    repo.fetchFailure = null;
    await tester.tap(find.text('Tải lại hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Mai'), findsOneWidget);
  });

  testWidgets('revocation and account switch reject old results',
      (tester) async {
    final repo = FakeProfileRepository()
      ..pendingRead = Completer<HealthProfile>();
    final controller = ProfileController(repo);
    addTearDown(controller.dispose);
    await showHome(tester, controller);
    controller.revoke();
    repo.pendingRead!.complete(const HealthProfile(fullName: 'Tên cũ'));
    await tester.pumpAndSettle();
    expect(find.text('Tên cũ'), findsNothing);
    expect(controller.profile, isNull);
    expect(find.text('Cần đồng ý xử lý dữ liệu sức khỏe để tiếp tục.'),
        findsOneWidget);
  });
}
