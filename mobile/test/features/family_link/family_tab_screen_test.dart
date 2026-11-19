import 'package:drugtime_mobile/features/family/presentation/screens/family_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/scan_link_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_controller.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_scope.dart';
import '../family/family_alert_controller_test.dart' show AlertRepo;
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_models.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_screen.dart';
import '../patient_monitor/patient_monitor_controller_test.dart'
    show MonitorRepo;

import 'family_link_test_helpers.dart';

/// 09:00 sáng 19/11 giờ VN.
final hubNow = DateTime.utc(2026, 11, 19, 2);
DateTime _vn(int h, [int m = 0]) =>
    DateTime.utc(2026, 11, 19, h, m).subtract(const Duration(hours: 7));

AdherenceDose _dose(int id, String name, DateTime at,
        {AdherenceDoseStatus status = AdherenceDoseStatus.pending,
        DateTime? takenAt}) =>
    AdherenceDose(
        medicationId: id,
        medicationName: name,
        scheduleId: id,
        scheduledAt: at,
        takenAt: takenAt,
        status: status);

const _summary = AdherenceSummary(
    total: 0, taken: 0, late: 0, missed: 0, pending: 0, counted: 0, rate: null);

MonitorSnapshot hubSnapshot(String id) {
  final doses = id == 'mother'
      ? [
          _dose(1, 'Losartan', _vn(6, 30), status: AdherenceDoseStatus.missed),
          _dose(2, 'Vitamin D3', _vn(7),
              status: AdherenceDoseStatus.taken, takenAt: _vn(7, 2)),
          _dose(3, 'Metformin', _vn(12)),
          _dose(4, 'Warfarin', _vn(20)),
        ]
      : [
          _dose(5, 'Amlodipine', _vn(7),
              status: AdherenceDoseStatus.taken, takenAt: _vn(7, 5)),
        ];
  final day = DateTime.utc(2026, 11, 19);
  return MonitorSnapshot(
      id,
      const [],
      MonitorHistory(
          AdherenceHistory(
              patientId: id,
              from: day.subtract(const Duration(days: 6)),
              to: day,
              asOf: hubNow,
              summary: _summary,
              groups: [
                AdherenceDateGroup(date: day, summary: _summary, doses: doses)
              ]),
          null),
      const []);
}

class _HubRepo extends MonitorRepo {
  @override
  Future<MonitorSnapshot> today(String patientId,
          {required DateTime now, bool includeMedications = true}) async =>
      hubSnapshot(patientId);
}

void main() {
  testWidgets(
      'alert entry displays server unread count and removes it after clear',
      (tester) async {
    final c = FamilyAlertController(AlertRepo())..setSession('A', ready: true);
    await c.load();
    await tester.pumpWidget(FamilyAlertScope(
        controller: c, child: const MaterialApp(home: FamilyTabScreen())));
    expect(find.text('1 chưa đọc'), findsOneWidget);
    expect(find.byKey(const Key('family-alerts')), findsOneWidget);
    c.clear();
    await tester.pump();
    expect(find.text('1 chưa đọc'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  Future<void> pumpTab(WidgetTester tester) => pumpFamilyLink(
        tester,
        const FamilyTabScreen(),
        repository: InMemoryFamilyLinkRepository(),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('family-follow')));
    await tester.pumpAndSettle();
  }

  testWidgets('AC11: Theo dõi người thân → hai lựa chọn Quét mã QR và Nhập mã',
      (tester) async {
    await pumpTab(tester);

    expect(find.text('Theo dõi người thân'), findsOneWidget);
    await openSheet(tester);

    expect(find.byKey(const Key('follow-method-scan')), findsOneWidget);
    expect(find.byKey(const Key('follow-method-enter')), findsOneWidget);
  });

  testWidgets('AC11: Quét mã QR mở màn quét', (tester) async {
    await pumpTab(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('follow-method-scan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ScanLinkQrScreen), findsOneWidget);
  });

  testWidgets('AC11: Nhập mã mở màn nhập mã', (tester) async {
    await pumpTab(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('follow-method-enter')));
    await tester.pumpAndSettle();

    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
  });

  group('hub người thân có dữ liệu theo dõi', () {
    Future<PatientMonitorController> pumpHub(WidgetTester tester,
        {required List<LinkedPatient> patients}) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // cảnh khu vườn và linh vật chạy ticker liên tục; giảm chuyển động để pumpAndSettle dừng
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final repo = _HubRepo()..directory = patients;
      final controller = PatientMonitorController(repo, clock: () => hubNow);
      final consent = ConsentController(InMemoryConsentRepository());
      final invites = InviteLinkController();
      await consent.load();
      controller.setSession('Nam', available: true);
      addTearDown(controller.dispose);
      addTearDown(consent.dispose);
      addTearDown(invites.dispose);
      await tester.pumpWidget(ConsentScope(
          controller: consent,
          child: FamilyLinkScope(
              repository: InMemoryFamilyLinkRepository(),
              caregivers: InMemoryCaregiverRepository(),
              invites: invites,
              monitor: controller,
              child: MaterialApp(
                  theme: buildAppTheme(),
                  onGenerateRoute: onGenerateRoute,
                  home: const FamilyTabScreen()))));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets(
        'R1e: chưa theo dõi ai → cảnh vườn trống, 3 bước, Quét / Nhập mã (AC1)',
        (tester) async {
      await pumpHub(tester, patients: const []);
      expect(find.byKey(const Key('family-empty')), findsOneWidget);
      expect(find.text('Bạn chưa theo dõi ai'), findsOneWidget);
      expect(find.textContaining('Chia sẻ và liên kết'), findsOneWidget);
      expect(find.byKey(const Key('family-garden')), findsOneWidget);
      expect(find.byKey(const Key('family-follow')), findsNothing);
      await tester.tap(find.byKey(const Key('family-empty-enter')));
      await tester.pumpAndSettle();
      expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('family-empty-scan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ScanLinkQrScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'R1: mỗi người một card + một chậu cây, thanh chia đoạn đúng (AC3)',
        (tester) async {
      await pumpHub(tester, patients: const [
        LinkedPatient(id: 'mother', name: 'Mẹ Hoa'),
        LinkedPatient(id: 'father', name: 'Bố Minh'),
      ]);
      expect(find.text('Tôi theo dõi · 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('patient-mother')), findsOneWidget);
      expect(find.byKey(const ValueKey('patient-father')), findsOneWidget);
      expect(find.text('1/4 liều · Bỏ lỡ Losartan 06:30'), findsOneWidget);
      expect(find.text('Liều tới: 12:00 Metformin'), findsOneWidget);
      expect(find.text('1/1 liều · Đã uống đủ hôm nay'), findsOneWidget);
      for (final key in [
        'dose-segment-0-missed',
        'dose-segment-1-taken',
        'dose-segment-2-upcoming',
        'dose-segment-3-upcoming',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(find.byKey(const Key('garden-plant-mother')), findsOneWidget);
      expect(find.byKey(const Key('garden-plant-father')), findsOneWidget);
      expect(find.byKey(const Key('family-follow')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chạm chậu cây của Bố mở đúng màn của Bố (AC18)',
        (tester) async {
      final controller = await pumpHub(tester, patients: const [
        LinkedPatient(id: 'mother', name: 'Mẹ Hoa'),
        LinkedPatient(id: 'father', name: 'Bố Minh'),
      ]);
      await tester.tap(find.byKey(const Key('garden-plant-father')));
      await tester.pumpAndSettle();
      expect(find.byType(PatientMonitorScreen), findsOneWidget);
      expect(controller.patientId, 'father');
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Mã liên kết của tôi mở màn QR của 3.11', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.byKey(const Key('family-my-code')));
    await tester.pumpAndSettle();

    expect(find.byType(FamilyLinkCodeScreen), findsOneWidget);
    expect(find.byKey(const Key('family-link-code')), findsOneWidget);
  });
}
