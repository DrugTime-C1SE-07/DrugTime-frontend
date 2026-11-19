import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_models.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_screen.dart';
import 'patient_monitor_controller_test.dart' show MonitorRepo, now;

class RichMonitorRepo extends MonitorRepo {
  @override
  Future<MonitorSnapshot> today(String patientId,
      {required DateTime now, bool includeMedications = true}) async {
    final base = await super
        .today(patientId, now: now, includeMedications: includeMedications);
    return MonitorSnapshot(patientId, base.schedules, base.report, [
      const Medication(
          id: '1',
          catalogId: '10',
          name: 'Thuốc khi cần',
          activeIngredient: '',
          strength: '',
          unit: 'viên',
          dosePerIntake: 1,
          frequency: DoseFrequency.asNeeded,
          timing: IntakeTiming.anytime),
      const Medication(
          id: '2',
          catalogId: '11',
          name: 'Thuốc hết',
          activeIngredient: '',
          strength: '5 mg',
          unit: 'viên',
          dosePerIntake: 1,
          frequency: DoseFrequency.once,
          timing: IntakeTiming.anytime,
          stockRemaining: 0),
    ]);
  }

  @override
  Future<MonitorHistory> history(
          String patientId, DateTime from, DateTime to) async =>
      MonitorHistory(
          AdherenceHistory(
              patientId: patientId,
              from: from,
              to: to,
              asOf: now,
              summary: const AdherenceSummary(
                  total: 28,
                  taken: 26,
                  late: 1,
                  missed: 1,
                  pending: 0,
                  counted: 28,
                  rate: 96.43),
              groups: []),
          null);
}

void main() {
  testWidgets(
      '320dp hub with large text and duplicate long names selects by ID',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = MonitorRepo()
      ..directory = const [
        LinkedPatient(
            id: 'mother', name: 'Nguyễn Thị Hoa có tên hiển thị rất dài'),
        LinkedPatient(
            id: 'father', name: 'Nguyễn Thị Hoa có tên hiển thị rất dài'),
        LinkedPatient(id: 'unnamed'),
      ];
    final controller = PatientMonitorController(repo, clock: () => now);
    final consent = ConsentController(InMemoryConsentRepository());
    final invites = InviteLinkController();
    await consent.load();
    controller.setSession('Nam', available: true);
    await tester.pumpWidget(ConsentScope(
        controller: consent,
        child: FamilyLinkScope(
            repository: InMemoryFamilyLinkRepository(),
            caregivers: InMemoryCaregiverRepository(),
            invites: invites,
            monitor: controller,
            child: MaterialApp(
                theme: buildAppTheme(),
                builder: (_, child) => MediaQuery(
                    data:
                        const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: child!),
                home: const FamilyTabScreen()))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('patient-mother')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('patient-father')), 200);
    expect(find.byKey(const ValueKey('patient-father')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('patient-unnamed')), 200);
    expect(find.text('Người bệnh'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    consent.dispose();
    invites.dispose();
  });
  testWidgets(
      'read-only meals, PRN/stock, server rate and R8 clear across subviews',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller =
        PatientMonitorController(RichMonitorRepo(), clock: () => now);
    final invites = InviteLinkController();
    controller.setSession('Nam', available: true);
    await controller.loadHub();
    await controller.select('mother');
    await tester.pumpWidget(FamilyLinkScope(
        repository: InMemoryFamilyLinkRepository(),
        caregivers: InMemoryCaregiverRepository(),
        invites: invites,
        monitor: controller,
        child: MaterialApp(
            theme: buildAppTheme(),
            home: const PatientMonitorScreen(patientId: 'mother'))));
    await tester.tap(find.text('Xem hôm nay'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xem bữa ăn minh họa'));
    await tester.tap(find.text('Xem bữa ăn minh họa'));
    await tester.pumpAndSettle();
    expect(find.text(mealMockLabel), findsOneWidget);
    expect(find.text('Bữa tối'), findsOneWidget);
    expect(find.text('Chưa chọn'), findsOneWidget);
    expect(find.textContaining('Hợp với'), findsNothing);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tủ thuốc'));
    await tester.tap(find.text('Tủ thuốc'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa cập nhật số lượng'), findsOneWidget);
    expect(find.text('Hết thuốc'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lịch sử tuân thủ'));
    await tester.tap(find.text('Lịch sử tuân thủ'));
    await tester.pumpAndSettle();
    expect(find.text('96.43%'), findsOneWidget);
    expect(find.text('Tỷ lệ tuân thủ'), findsOneWidget);
    controller.revoke('mother');
    await tester.pump();
    expect(find.text('96.43%'), findsNothing);
    expect(find.text('Hoa'), findsNothing);
    expect(find.text('Hiện không thể truy cập dữ liệu được chia sẻ'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    invites.dispose();
  });
}
