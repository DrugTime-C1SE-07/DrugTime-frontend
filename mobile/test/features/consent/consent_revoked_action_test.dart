import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/consent_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'consent_test_helpers.dart';

/// AC15: lỗi `consent_revoked` mời người dùng đồng ý và có nút mở màn đồng ý.
void main() {
  test('câu mới mời đồng ý, không còn giả định đã từng đồng ý', () {
    final message = medicationErrorMessage(
      const MedicationFailure(MedicationFailureKind.consentRevoked),
    );

    expect(message, contains('đồng ý'));
    expect(message, isNot(contains('Bật lại')));
    expect(message, isNot(contains('đã tắt')));
  });

  /// Đã đồng ý lúc onboarding, rồi rút health_data ở màn Quyền riêng tư (AC16 ở dạng test).
  Future<RecordingConsentRepository> withdrawThenBackToMedications(WidgetTester tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData});
    await pumpConsentApp(tester, consents: repo, medications: ConsentAwareMedicationRepository(repo));

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacy-settings-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    await tester.tap(consentSwitch(ConsentPurpose.healthData));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-withdraw-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget, reason: 'màn Quyền riêng tư có nút quay lại');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thuốc'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('thẻ lỗi ở danh sách thuốc có nút mở màn đồng ý; đồng ý xong thì tải lại',
      (tester) async {
    final repo = await withdrawThenBackToMedications(tester);

    expect(find.textContaining('cần bạn đồng ý'), findsOneWidget);
    final action = find.byKey(const Key('consent-revoked-card-action'));
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    await tester.tap(consentSwitch(ConsentPurpose.healthData));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentScreen), findsNothing);
    expect(repo.writes.last, 'grant:health_data');
    expect(find.textContaining('cần bạn đồng ý'), findsNothing);
  });

  testWidgets('SnackBar lỗi consent_revoked có nút "Đồng ý" mở màn đồng ý', (tester) async {
    await pumpConsentApp(tester, consents: RecordingConsentRepository(granted: {
      ConsentPurpose.healthData,
    }));
    final context = tester.element(find.byType(Scaffold).first);

    showMedicationFailure(
      context,
      const MedicationFailure(MedicationFailureKind.consentRevoked),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('consent-revoked-action'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);
  });

  testWidgets('lỗi khác không có nút đồng ý', (tester) async {
    await pumpConsentApp(tester, consents: RecordingConsentRepository(granted: {
      ConsentPurpose.healthData,
    }));
    final context = tester.element(find.byType(Scaffold).first);

    showMedicationFailure(context, const MedicationFailure(MedicationFailureKind.network));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-revoked-action')), findsNothing);
  });
}
