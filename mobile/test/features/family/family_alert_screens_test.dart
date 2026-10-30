import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/family/presentation/screens/family_alert_inbox_screen.dart';
import 'package:drugtime_mobile/features/family/presentation/screens/family_alert_detail_screen.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_controller.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_scope.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_alert.dart';
import 'family_alert_controller_test.dart' show AlertRepo;
import 'remote_family_alert_repository_test.dart' show alertJson;

void main() {
  testWidgets(
      'iOS inbox has support note, patient, medicine, VN day and read status',
      (tester) async {
    final c = FamilyAlertController(AlertRepo())..setSession('A', ready: true);
    await tester.pumpWidget(FamilyAlertScope(
        controller: c,
        child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: const FamilyAlertInboxScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo đẩy chưa được hỗ trợ'), findsOneWidget);
    expect(find.text('Bác An'), findsOneWidget);
    expect(find.textContaining('02:30 · 22/10/2026'), findsOneWidget);
    expect(find.text('Chưa đọc'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'detail is read only, legacy fallback and server confirmed mark-read',
      (tester) async {
    final repo = AlertRepo()
      ..onDetail = () async => FamilyAlert.fromJson(
          {...alertJson(), 'medication_name': null, 'scheduled_at': null});
    final c = FamilyAlertController(repo)..setSession('A', ready: true);
    await tester.pumpWidget(FamilyAlertScope(
        controller: c,
        child: const MaterialApp(home: FamilyAlertDetailScreen(id: 1))));
    await tester.pumpAndSettle();
    expect(find.text('Không có dữ liệu liều cũ'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();
    expect(find.text('Đã đọc'), findsOneWidget);
    expect(c.unreadCount, 0);
    c.clear();
    await tester.pump();
    expect(find.text('Bác An'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
