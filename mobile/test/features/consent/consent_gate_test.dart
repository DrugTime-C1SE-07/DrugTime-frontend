import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent_failure.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/consent_screen.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'consent_test_helpers.dart';

/// AC13: mở app có phiên, hồ sơ đủ → cổng ở Trang chủ quyết định theo GET /consents.
void main() {
  testWidgets('chưa có health_data → màn đồng ý thay cho Trang chủ', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.aiMeal});
    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(repo.calls.first, 'fetchAll');
  });

  testWidgets('đã có health_data → vào AppShell như cũ', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData});
    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ConsentScreen), findsNothing);
  });

  testWidgets('không tải được consent (mất mạng) → vẫn vào AppShell', (tester) async {
    final repo = RecordingConsentRepository()
      ..failFetch = const ConsentFailure(ConsentFailureKind.network);
    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ConsentScreen), findsNothing);
  });

  testWidgets('không truyền repository: mặc định đã đồng ý health_data, vào thẳng AppShell',
      (tester) async {
    // Bản web xem thử và các widget test cũ dựng DrugTimeApp không truyền consentRepository.
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DrugTimeApp(
      authController: signedInAuth(),
      medicationRepository: InMemoryMedicationRepository(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ConsentScreen), findsNothing);
  });
}
