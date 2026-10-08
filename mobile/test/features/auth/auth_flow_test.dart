import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/login_method.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/terms_update_screen.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../consent/consent_test_helpers.dart';

AuthSession _session({required bool profileComplete}) => AuthSession(
      userId: 'u-1',
      accessToken: 'app-token',
      expiresAt: DateTime.now().add(const Duration(days: 10)),
      profileComplete: profileComplete,
    );

InMemoryAuthRepository _repo({AuthSession? session}) =>
    InMemoryAuthRepository(initialSession: session, simulatedDelay: Duration.zero);

Future<AuthController> _pumpApp(
  WidgetTester tester,
  InMemoryAuthRepository repo, {
  AuthController? controller,
  String? initialRoute,
  InMemoryConsentRepository? consents,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = controller ?? AuthController(repo);
  await tester.pumpWidget(DrugTimeApp(
    authController: auth,
    consentRepository: consents,
    medicationRepository: InMemoryMedicationRepository(),
    initialRoute: initialRoute,
  ));
  await tester.pumpAndSettle();
  return auth;
}

/// Đã gửi OTP tới email (bước màn Đăng nhập), app mở ở màn nhập OTP.
Future<AuthController> _atEmailOtp(WidgetTester tester, InMemoryAuthRepository repo) async {
  final controller = AuthController(repo)..setMethod(LoginMethod.email);
  await controller.requestOtp('lan@example.com');
  return _pumpApp(tester, repo, controller: controller, initialRoute: AppRoutes.otpEmail);
}

Future<void> _enterOtp(WidgetTester tester, String code) async {
  await tester.enterText(
    find.descendant(of: find.byType(OtpVerificationScreen), matching: find.byType(TextField)),
    code,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('(a) chưa có phiên → màn Đăng nhập', (tester) async {
    await _pumpApp(tester, _repo());

    expect(find.byType(LoginMobileScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  Future<void> enterPhoneAndSend(WidgetTester tester, {required bool tick}) async {
    await tester.enterText(
      find.descendant(of: find.byType(PhoneInputField), matching: find.byType(TextField)),
      '0900000001',
    );
    if (tick) {
      await tester.ensureVisible(find.byKey(const Key('terms-checkbox')));
      await tester.tap(find.byKey(const Key('terms-checkbox')));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Gửi mã OTP'));
    await tester.tap(find.text('Gửi mã OTP'));
    await tester.pumpAndSettle();
  }

  testWidgets('(h) màn Đăng nhập chưa tick điều khoản → không gửi OTP', (tester) async {
    final repo = _repo();
    await _pumpApp(tester, repo);

    await enterPhoneAndSend(tester, tick: false);

    expect(repo.requestedPhoneOtps, isEmpty);
    expect(find.byType(LoginMobileScreen), findsOneWidget);
    expect(find.byType(OtpVerificationScreen), findsNothing);
  });

  testWidgets('(i) AC19: tick → OTP đúng → ghi terms một lần, không hỏi lại điều khoản',
      (tester) async {
    final repo = _repo()..verifiedProfileComplete = true;
    final consents = RecordingConsentRepository(
      granted: {ConsentPurpose.healthData},
      termsAccepted: false,
    );
    await _pumpApp(tester, repo, consents: consents);

    await enterPhoneAndSend(tester, tick: true);
    expect(repo.requestedPhoneOtps, ['+84900000001']);
    await _enterOtp(tester, '123456');

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TermsUpdateScreen), findsNothing);
    expect(consents.writes, ['grant:terms']);
  });

  testWidgets('(b) OTP đúng, người mới → màn hồ sơ → lưu → Trang chủ', (tester) async {
    final repo = _repo()..verifiedProfileComplete = false;
    await _atEmailOtp(tester, repo);

    await _enterOtp(tester, '123456');
    expect(find.byType(CompleteProfileScreen), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-full-name')), 'Nguyễn Thị Lan');
    await tester.tap(find.byKey(const Key('profile-date-of-birth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nữ'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(repo.completedProfiles.single.$1, 'Nguyễn Thị Lan');
    expect(repo.completedProfiles.single.$3, 'nu');
    expect((await repo.getCurrentSession())?.profileComplete, isTrue);
  });

  testWidgets('(b2) hồ sơ thiếu giới tính → báo lỗi, ở lại màn hồ sơ', (tester) async {
    final repo = _repo(session: _session(profileComplete: false));
    await _pumpApp(tester, repo);

    await tester.enterText(find.byKey(const Key('profile-full-name')), 'Lan');
    await tester.tap(find.byKey(const Key('profile-date-of-birth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng chọn giới tính'), findsOneWidget);
    expect(find.byType(CompleteProfileScreen), findsOneWidget);
    expect(repo.completedProfiles, isEmpty);
  });

  testWidgets('(c) phiên đã lưu, có hồ sơ → vào thẳng Trang chủ', (tester) async {
    await _pumpApp(tester, _repo(session: _session(profileComplete: true)));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(LoginMobileScreen), findsNothing);
  });

  testWidgets('(d) phiên đã lưu, chưa có hồ sơ → màn hồ sơ', (tester) async {
    await _pumpApp(tester, _repo(session: _session(profileComplete: false)));

    expect(find.byType(CompleteProfileScreen), findsOneWidget);
  });

  testWidgets('(d2) phiên đã hết hạn → màn Đăng nhập', (tester) async {
    final expired = AuthSession(
      userId: 'u-1',
      accessToken: 'app-token',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      profileComplete: true,
    );
    await _pumpApp(tester, _repo(session: expired));

    expect(find.byType(LoginMobileScreen), findsOneWidget);
  });

  testWidgets('(e) Đăng xuất → màn Đăng nhập, phiên bị xóa', (tester) async {
    final repo = _repo(session: _session(profileComplete: true));
    await _pumpApp(tester, repo);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-tile')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginMobileScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(await repo.getCurrentSession(), isNull);
  });

  testWidgets('(f) API báo 401 (handleUnauthorized) → màn Đăng nhập', (tester) async {
    final auth = await _pumpApp(tester, _repo(session: _session(profileComplete: true)));
    expect(find.byType(AppShell), findsOneWidget);

    await auth.handleUnauthorized();
    await tester.pumpAndSettle();

    expect(find.byType(LoginMobileScreen), findsOneWidget);
  });

  testWidgets('(g) OTP sai → thông báo lỗi, vẫn ở màn OTP', (tester) async {
    final repo = _repo();
    await _atEmailOtp(tester, repo);

    await _enterOtp(tester, '000000');

    expect(find.text('Mã OTP không đúng hoặc đã hết hạn'), findsWidgets);
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
    expect(await repo.getCurrentSession(), isNull);
  });
}
