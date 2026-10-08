import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/consent_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/legal_document_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'consent_test_helpers.dart';

/// AC12: màn đồng ý ở onboarding (người dùng chưa có health_data).
void main() {
  Finder continueButton() => find.byKey(const Key('consent-continue'));

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(continueButton()).onPressed != null;

  Future<void> tapSwitch(WidgetTester tester, ConsentPurpose purpose) async {
    await tester.ensureVisible(consentSwitch(purpose));
    await tester.tap(consentSwitch(purpose));
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(continueButton());
    await tester.tap(continueButton());
    await tester.pumpAndSettle();
  }

  testWidgets('ba mục đích, mỗi mục một công tắc mặc định tắt, không có nút đồng ý tất cả',
      (tester) async {
    await pumpConsentApp(tester, consents: RecordingConsentRepository());

    expect(find.byType(ConsentScreen), findsOneWidget);
    for (final purpose in ConsentPurpose.toggleable) {
      expect(consentSwitch(purpose), findsOneWidget);
      expect(switchValue(tester, purpose), isFalse);
    }
    expect(find.byType(Switch), findsNWidgets(3));
    expect(find.textContaining(RegExp('tất cả', caseSensitive: false)), findsNothing);
    expect(find.text('Bắt buộc'), findsOneWidget);
    expect(find.text('Tùy chọn'), findsNWidgets(2));
  });

  testWidgets('chưa bật health_data thì không tiếp tục được và không gọi API ghi',
      (tester) async {
    final repo = RecordingConsentRepository();
    await pumpConsentApp(tester, consents: repo);

    expect(continueEnabled(tester), isFalse);
    expect(find.byKey(const Key('consent-required-hint')), findsOneWidget);

    // Bật hai mục tùy chọn vẫn chưa đủ.
    await tapSwitch(tester, ConsentPurpose.familySharing);
    await tapSwitch(tester, ConsentPurpose.aiMeal);
    expect(continueEnabled(tester), isFalse);
    await tapContinue(tester);

    expect(repo.writes, isEmpty);
    expect(find.byType(ConsentScreen), findsOneWidget);
  });

  testWidgets('chỉ bật health_data: grant đúng một lần rồi vào AppShell', (tester) async {
    final repo = RecordingConsentRepository();
    await pumpConsentApp(tester, consents: repo);

    await tapSwitch(tester, ConsentPurpose.healthData);
    expect(continueEnabled(tester), isTrue);
    await tapContinue(tester);

    expect(repo.writes, ['grant:health_data']);
    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('bật health_data và ai_meal: mỗi mục đang bật grant đúng một lần', (tester) async {
    final repo = RecordingConsentRepository();
    await pumpConsentApp(tester, consents: repo);

    await tapSwitch(tester, ConsentPurpose.healthData);
    await tapSwitch(tester, ConsentPurpose.aiMeal);
    await tapContinue(tester);

    expect(repo.writes, ['grant:health_data', 'grant:ai_meal']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('lỗi mạng: ở lại màn, báo lỗi; bấm lại chỉ gửi mục chưa thành công',
      (tester) async {
    final repo = RecordingConsentRepository()..failOnWrite = 2; // family_sharing lỗi lần đầu
    await pumpConsentApp(tester, consents: repo);
    await tapSwitch(tester, ConsentPurpose.healthData);
    await tapSwitch(tester, ConsentPurpose.familySharing);

    await tapContinue(tester);

    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);

    await tapContinue(tester);

    expect(repo.writes, ['grant:health_data', 'grant:family_sharing', 'grant:family_sharing']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('sau khi đồng ý thì tải lại danh sách thuốc (lần trước bị 403)', (tester) async {
    final repo = RecordingConsentRepository();
    final meds = ConsentAwareMedicationRepository(repo);
    await pumpConsentApp(tester, consents: repo, medications: meds);
    final before = meds.fetchCount;

    await tapSwitch(tester, ConsentPurpose.healthData);
    await tapContinue(tester);

    expect(meds.fetchCount, greaterThan(before));
    expect(find.textContaining('cần bạn đồng ý'), findsNothing);
  });

  group('AC23: điều khoản không phải công tắc', () {
    testWidgets('màn đồng ý: server có terms nhưng không có công tắc terms', (tester) async {
      await pumpConsentApp(tester, consents: RecordingConsentRepository());

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(consentSwitch(ConsentPurpose.terms), findsNothing);
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('màn Quyền riêng tư: không có công tắc terms, có link hai văn bản', (tester) async {
      final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData});
      await pumpConsentApp(tester, consents: repo, initialRoute: AppRoutes.privacySettings);

      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
      expect(consentSwitch(ConsentPurpose.terms), findsNothing);
      expect(find.byType(Switch), findsNWidgets(3));

      for (final (key, title) in [
        ('privacy-link-terms', 'Điều khoản dịch vụ'),
        ('privacy-link-privacy', 'Chính sách quyền riêng tư'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.byType(LegalDocumentScreen), findsOneWidget);
        expect(find.widgetWithText(AppBar, title), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(repo.writes, isEmpty);
    });
  });
}
