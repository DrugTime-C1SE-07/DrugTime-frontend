import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_history_screen.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/repositories/caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpLoggedIn(WidgetTester tester, {CaregiverRepository? caregivers}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(DrugTimeApp(
    caregiverRepository: caregivers,
    authController: AuthController(InMemoryAuthRepository(
      initialSession: AuthSession(
        userId: 'u-1',
        accessToken: 'app-token',
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        profileComplete: true,
      ),
      simulatedDelay: Duration.zero,
    )),
    medicationRepository: InMemoryMedicationRepository(),
  ));
  await tester.pumpAndSettle();
  expect(find.byType(AppShell), findsOneWidget);
}

void main() {
  testWidgets('tab Lịch nhắc mở lịch sử tuân thủ, không dùng dữ liệu mẫu',
      (tester) async {
    await _pumpLoggedIn(tester);
    await tester.tap(find.text('Lịch nhắc'));
    await tester.pumpAndSettle();
    expect(find.byType(AdherenceHistoryScreen), findsOneWidget);
    expect(find.byKey(const Key('history-title')), findsOneWidget);
    expect(
        find.text('Chưa có kết nối Backend để xem lịch sử.'), findsOneWidget);
  });
  testWidgets('AC24: tab Hồ sơ là ProfileScreen, không còn danh sách dev',
      (tester) async {
    await _pumpLoggedIn(tester);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('supervisors-tile')), findsOneWidget);
    expect(find.textContaining('UI Catalog'), findsNothing);
    expect(find.text('S00c · Màn hình Đăng nhập (OTP)'), findsNothing);
  });

  testWidgets('AC25: menu cài đặt của Hồ sơ chỉ còn Đăng xuất', (tester) async {
    await _pumpLoggedIn(tester);
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.textContaining('UI Catalog'), findsNothing);
  });

  testWidgets('tab Người thân là FamilyTabScreen', (tester) async {
    await _pumpLoggedIn(tester);

    await tester.tap(find.text('Người thân'));
    await tester.pumpAndSettle();

    expect(find.byType(FamilyTabScreen), findsOneWidget);
  });

  testWidgets('AC16: chuyển sang tab Người thân thì tải lại yêu cầu đang chờ', (tester) async {
    final caregivers = InMemoryCaregiverRepository();
    await _pumpLoggedIn(tester, caregivers: caregivers);

    // Shell mở ở tab Thuốc: tab Người thân chưa hiển thị nên chưa tải.
    expect(caregivers.calls, isEmpty);

    await tester.tap(find.text('Người thân'));
    await tester.pumpAndSettle();
    expect(caregivers.calls, ['listPendingRequests']);

    await tester.tap(find.text('Thuốc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người thân'));
    await tester.pumpAndSettle();
    expect(caregivers.calls, ['listPendingRequests', 'listPendingRequests']);
  });

  testWidgets('AC20: Người giám sát trống → Mở tab Người thân về đúng tab', (tester) async {
    final caregivers = InMemoryCaregiverRepository();
    await _pumpLoggedIn(tester, caregivers: caregivers);
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('supervisors-tile')));
    await tester.tap(find.byKey(const Key('supervisors-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('caregivers-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('caregivers-open-family-tab')));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, AppTab.family.index);
    expect(caregivers.calls, ['listCaregivers', 'listPendingRequests']);
  });

  test('AC25: không còn route /dev-catalog', () {
    expect(onGenerateRoute(const RouteSettings(name: '/dev-catalog')), isNull);
  });
}
