import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent_failure.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/consent_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/legal_document_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/terms_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'consent_test_helpers.dart';

/// Bước điều khoản của cổng ở Trang chủ (AC19, AC20, AC21). Mọi test đặt trạng thái `terms`
/// tường minh, không dựa vào mặc định của repository.
void main() {
  final checkbox = find.byKey(const Key('terms-checkbox'));
  final continueButton = find.byKey(const Key('terms-update-continue'));

  Future<void> accept(WidgetTester tester) async {
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }

  testWidgets('(a) AC19: đã tick ở màn đăng nhập → ghi terms ngầm đúng một lần, trước health_data',
      (tester) async {
    final repo = RecordingConsentRepository(termsAccepted: false);
    final auth = signedInAuth()..setTermsAccepted(true);

    await pumpConsentApp(tester, consents: repo, auth: auth);

    expect(repo.writes, ['grant:terms']);
    expect(repo.calls.first, 'fetchAll');
    expect(find.byType(TermsUpdateScreen), findsNothing);
    expect(find.byType(ConsentScreen), findsOneWidget); // chưa có health_data
  });

  testWidgets('(a) đã tick, đã có health_data → ghi terms rồi vào thẳng AppShell', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData}, termsAccepted: false);
    final auth = signedInAuth()..setTermsAccepted(true);

    await pumpConsentApp(tester, consents: repo, auth: auth);

    expect(repo.writes, ['grant:terms']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('đã tick nhưng server đã có terms bản hiện hành → không ghi gì', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData});
    final auth = signedInAuth()..setTermsAccepted(true);

    await pumpConsentApp(tester, consents: repo, auth: auth);

    expect(repo.writes, isEmpty);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('(b) AC20: có phiên, chưa đồng ý điều khoản → màn điều khoản; chưa tick không đi tiếp',
      (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData}, termsAccepted: false);
    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(TermsUpdateScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('terms-error')), findsOneWidget);
    expect(repo.writes, isEmpty);
    expect(find.byType(TermsUpdateScreen), findsOneWidget);

    await accept(tester);
    expect(repo.writes, ['grant:terms']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('(b) chưa có cả terms lẫn health_data → điều khoản trước, rồi màn đồng ý',
      (tester) async {
    final repo = RecordingConsentRepository(termsAccepted: false);
    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(TermsUpdateScreen), findsOneWidget);
    await accept(tester);

    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(repo.writes, ['grant:terms']);
  });

  testWidgets('(c) AC21: đã đồng ý điều khoản bản cũ → hỏi lại', (tester) async {
    final repo = RecordingConsentRepository(
      granted: {ConsentPurpose.healthData},
      grantedVersions: const {ConsentPurpose.terms: '2026-09-v0'},
    );
    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(TermsUpdateScreen), findsOneWidget);
    await accept(tester);

    expect(repo.writes, ['grant:terms']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('(d) ghi terms ngầm lỗi mạng → hiện màn điều khoản', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData}, termsAccepted: false)
      ..failOnWrite = 1;
    final auth = signedInAuth()..setTermsAccepted(true);

    await pumpConsentApp(tester, consents: repo, auth: auth);

    expect(repo.writes, ['grant:terms']);
    expect(find.byType(TermsUpdateScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('(e) không tải được consent → vẫn vào AppShell như cũ', (tester) async {
    final repo = RecordingConsentRepository(termsAccepted: false)
      ..failFetch = const ConsentFailure(ConsentFailureKind.network);

    await pumpConsentApp(tester, consents: repo);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TermsUpdateScreen), findsNothing);
    expect(repo.writes, isEmpty);
  });

  testWidgets('đồng ý ở màn điều khoản lỗi → báo lỗi, ở lại màn', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData}, termsAccepted: false)
      ..failOnWrite = 1;
    await pumpConsentApp(tester, consents: repo);

    await accept(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(TermsUpdateScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('màn điều khoản: link mở văn bản, quay lại giữ tick', (tester) async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.healthData}, termsAccepted: false);
    await pumpConsentApp(tester, consents: repo);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('Chính sách quyền riêng tư'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(repo.writes, isEmpty);
  });
}
