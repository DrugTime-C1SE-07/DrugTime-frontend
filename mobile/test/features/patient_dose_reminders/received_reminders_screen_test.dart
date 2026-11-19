import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/data/patient_monitor_repository.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';
import 'package:drugtime_mobile/features/patient_dose_reminders/presentation/received_reminders_screen.dart';
import '../patient_monitor/patient_monitor_repository_test.dart'
    show historyJson;

void main() {
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
}
