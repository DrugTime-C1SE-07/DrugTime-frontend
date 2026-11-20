import '../patient_monitor/patient_monitor_repository_test.dart'
    show historyJson;
import 'dart:convert';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:drugtime_mobile/features/patient_dose_reminders/presentation/received_reminders_screen.dart';
import 'package:drugtime_mobile/features/patient_monitor/data/patient_monitor_repository.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_models.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final scheduledAt = DateTime.utc(2026, 11, 18, 23, 30); // 06:30 VN 19/11

class SelfRepo extends PatientMonitorRepository {
  SelfRepo({required this.taken})
      : super(ApiClient(
            baseUrl: Uri.parse('https://test.invalid'),
            httpClient: MockClient((r) async => http.Response(
                jsonEncode({
                  'id': 7,
                  'patient_id': 'me',
                  'schedule_id': 1,
                  'scheduled_at': scheduledAt.toIso8601String(),
                  'medication_name': 'Losartan',
                  'sender_name': 'Con Nam',
                  'is_read': true,
                }),
                200,
                headers: {'content-type': 'application/json'}))));
  final bool taken;

  @override
  Future<MonitorHistory> history(
      String patientId, DateTime from, DateTime to) async {
    const s = AdherenceSummary(
        total: 1,
        taken: 0,
        late: 1,
        missed: 0,
        pending: 0,
        counted: 1,
        rate: null);
    return MonitorHistory(
        AdherenceHistory(
            patientId: patientId,
            from: from,
            to: to,
            asOf: DateTime.utc(2026, 11, 19, 2),
            summary: s,
            groups: [
              AdherenceDateGroup(date: from, summary: s, doses: [
                AdherenceDose(
                    medicationId: 1,
                    medicationName: 'Losartan',
                    scheduleId: 1,
                    scheduledAt: scheduledAt,
                    takenAt: taken ? DateTime.utc(2026, 11, 19, 1, 20) : null,
                    status: taken
                        ? AdherenceDoseStatus.late
                        : AdherenceDoseStatus.missed),
              ])
            ]),
        null);
  }
}

Future<void> pumpInbox(WidgetTester tester, {required bool taken}) async {
  final controller = PatientMonitorController(SelfRepo(taken: taken));
  final consent = ConsentController(InMemoryConsentRepository(
      granted: {ConsentPurpose.terms, ConsentPurpose.healthData}));
  final invites = InviteLinkController();
  addTearDown(controller.dispose);
  addTearDown(consent.dispose);
  addTearDown(invites.dispose);
  await consent.load();
  controller.setSession('me', available: true);
  await tester.pumpWidget(ConsentScope(
      controller: consent,
      child: FamilyLinkScope(
          repository: InMemoryFamilyLinkRepository(),
          caregivers: InMemoryCaregiverRepository(),
          invites: invites,
          monitor: controller,
          child: const MaterialApp(
              home: ReceivedRemindersScreen(reminderId: 7)))));
  await tester.pumpAndSettle();
}

void main() {
  // Test hồi quy có sẵn từ trước task (khôi phục nguyên văn từ main).
  testWidgets(
      'tap rechecks current history, marks read only and clears on background',
      (tester) async {
    final calls = <String>[];
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          final detail = {
            'id': 9,
            'patient_id': 'patient',
            'schedule_id': 2,
            'scheduled_at': '2026-11-19T08:30:00+07:00',
            'requested_at': '2026-11-19T09:00:00+07:00',
            'is_read': true,
            'status': 'accepted',
            'medication_name': 'Thuốc nhận nhắc',
            'sender_name': 'Nam'
          };
          return http.Response(
              jsonEncode(request.url.path == '/adherence'
                  ? historyJson('patient')
                  : detail),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final controller = PatientMonitorController(PatientMonitorRepository(api))
      ..setSession('patient', available: true);
    final consents = ConsentController(InMemoryConsentRepository());
    await consents.load();
    final invites = InviteLinkController();
    await tester.pumpWidget(ConsentScope(
        controller: consents,
        child: FamilyLinkScope(
            repository: InMemoryFamilyLinkRepository(),
            caregivers: InMemoryCaregiverRepository(),
            invites: invites,
            monitor: controller,
            child: const MaterialApp(
                home: ReceivedRemindersScreen(reminderId: 9)))));
    await tester.pumpAndSettle();
    expect(find.text('Thuốc nhận nhắc'), findsOneWidget);
    expect(calls, [
      'GET /dose-reminders/received/9',
      'GET /adherence',
      'PATCH /dose-reminders/received/9'
    ]);
    expect(find.text('Mở lịch của tôi'), findsOneWidget);
    expect(find.textContaining('Bỏ qua'), findsNothing);
    controller.setSession('patient', available: false);
    await tester.pump();
    expect(find.text('Thuốc nhận nhắc'), findsNothing);
    expect(calls.where((call) => call.startsWith('POST ')), isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    consents.dispose();
    invites.dispose();
  });

  testWidgets('liều đã ghi nhận → "Bạn đã uống lúc HH:mm" (AC12)',
      (tester) async {
    await pumpInbox(tester, taken: true);
    expect(find.text('Losartan'), findsOneWidget);
    expect(find.text('Từ Con Nam'), findsOneWidget);
    expect(find.text('Bạn đã uống lúc 08:20'), findsOneWidget);
  });

  testWidgets('liều chưa ghi nhận → nhãn trạng thái như cũ', (tester) async {
    await pumpInbox(tester, taken: false);
    expect(find.text('Bỏ lỡ'), findsOneWidget);
    expect(find.textContaining('Bạn đã uống lúc'), findsNothing);
  });
}
