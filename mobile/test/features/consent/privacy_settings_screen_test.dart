import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent_failure.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'consent_test_helpers.dart';

/// AC14: màn Quyền riêng tư — bật là đồng ý, tắt phải xác nhận.
void main() {
  Future<RecordingConsentRepository> openPrivacy(
    WidgetTester tester, {
    Set<ConsentPurpose> granted = const {ConsentPurpose.healthData},
  }) async {
    final repo = RecordingConsentRepository(granted: granted);
    await pumpConsentApp(tester, consents: repo, initialRoute: AppRoutes.privacySettings);
    expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    return repo;
  }

  testWidgets('hiện trạng thái hiện tại của ba mục đích', (tester) async {
    await openPrivacy(tester, granted: {ConsentPurpose.healthData, ConsentPurpose.aiMeal});

    expect(switchValue(tester, ConsentPurpose.healthData), isTrue);
    expect(switchValue(tester, ConsentPurpose.familySharing), isFalse);
    expect(switchValue(tester, ConsentPurpose.aiMeal), isTrue);
  });

  testWidgets('tắt health_data: hộp xác nhận nêu hệ quả; Hủy thì không gọi API', (tester) async {
    final repo = await openPrivacy(tester);

    await tester.tap(consentSwitch(ConsentPurpose.healthData));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('không quản lý thuốc'), findsOneWidget);
    expect(find.textContaining('Người thân đang liên kết cũng mất quyền xem'), findsOneWidget);

    await tester.tap(find.byKey(const Key('consent-withdraw-cancel')));
    await tester.pumpAndSettle();

    expect(repo.writes, isEmpty);
    expect(switchValue(tester, ConsentPurpose.healthData), isTrue);
  });

  testWidgets('tắt health_data và xác nhận: gọi withdraw, công tắc tắt', (tester) async {
    final repo = await openPrivacy(tester);

    await tester.tap(consentSwitch(ConsentPurpose.healthData));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(repo.writes, ['withdraw:health_data']);
    expect(switchValue(tester, ConsentPurpose.healthData), isFalse);
  });

  testWidgets('rút lỗi mạng: công tắc trở về trạng thái cũ và có thông báo', (tester) async {
    final repo = await openPrivacy(tester);
    repo.failOnWrite = 1;

    await tester.tap(consentSwitch(ConsentPurpose.healthData));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('consent-withdraw-confirm')));
    await tester.pumpAndSettle();

    expect(repo.writes, ['withdraw:health_data']);
    expect(switchValue(tester, ConsentPurpose.healthData), isTrue);
    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
  });

  testWidgets('bật mục tùy chọn: gọi grant ngay, không hỏi xác nhận', (tester) async {
    final repo = await openPrivacy(tester);

    await tester.tap(consentSwitch(ConsentPurpose.familySharing));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.writes, ['grant:family_sharing']);
    expect(switchValue(tester, ConsentPurpose.familySharing), isTrue);
  });

  testWidgets('không tải được: báo lỗi và có nút thử lại', (tester) async {
    final repo = RecordingConsentRepository()
      ..failFetch = const ConsentFailure(ConsentFailureKind.network);
    await pumpConsentApp(tester, consents: repo, initialRoute: AppRoutes.privacySettings);

    expect(find.byKey(const Key('privacy-load-error')), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
