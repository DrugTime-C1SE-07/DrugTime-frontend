import 'dart:convert';

import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/notification/family_push_service.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/patient_monitor/data/patient_monitor_repository.dart';
import 'package:drugtime_mobile/features/reminder/presentation/screens/dose_reminder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../core/notification/device_token_coordinator_test.dart'
    show tokenSession;
import '../features/reminder/notification_navigation_flow_test.dart'
    show FakeTestKeyguardPlatform;
import '../features/patient_dose_reminders/caregiver_reminder_launcher_test.dart'
    show FakeStore, losartan, scheduledAt;

void main() {
  testWidgets(
      'chạm thông báo nhắc từ người thân → màn nhắc toàn phần "<tên> nhắc bạn" (AC10)',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final requests = <String>[];
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        httpClient: MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          if (r.url.path.endsWith('/dose-reminders/received/7')) {
            return http.Response(
                jsonEncode(r.method == 'GET'
                    ? {
                        'id': 7,
                        'patient_id': 'A',
                        'schedule_id': 1,
                        'scheduled_at': scheduledAt.toIso8601String(),
                        'medication_name': 'Losartan',
                        'sender_name': 'Con Nam',
                        'is_read': false,
                      }
                    : {'id': 7, 'is_read': true}),
                200,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(jsonEncode({'items': []}), 200,
              headers: {'content-type': 'application/json'});
        }));
    final auth = AuthController(InMemoryAuthRepository(
        initialSession: tokenSession('A'), simulatedDelay: Duration.zero));
    final push =
        FamilyPushService(android: false, showForeground: (_, __) async {})
          ..offerReminder('7'); // dữ liệu FCM luôn là chuỗi
    await tester.pumpWidget(DrugTimeApp(
      authController: auth,
      familyPushService: push,
      patientMonitorRepository: PatientMonitorRepository(api),
      localMedicationStore: FakeStore(schedule: losartan),
      keyguardPlatform: FakeTestKeyguardPlatform(),
      consentRepository: InMemoryConsentRepository(granted: {
        ConsentPurpose.terms,
        ConsentPurpose.healthData,
        ConsentPurpose.familySharing,
      }),
    ));
    // màn nhắc có hoạt họa nền; bơm từng khung thay vì chờ settle
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DoseReminderScreen), findsOneWidget);
    expect(find.text('DrugTime · Con Nam nhắc bạn'), findsOneWidget);
    expect(find.text('Losartan'), findsOneWidget);
    expect(find.text('Nhắc lại sau 10 phút'), findsNothing);
    expect(requests, contains('PATCH /dose-reminders/received/7'));
    await tester.pumpWidget(const SizedBox());
    push.dispose();
    auth.dispose();
  });
}
