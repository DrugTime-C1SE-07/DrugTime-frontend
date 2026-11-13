import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/login_method.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/login_segmented_picker.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/email_otp_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/email_input_field.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/legal_document_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/widgets/terms_agreement_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Màn đăng nhập: icon dòng phụ trợ (AC1, AC2, AC4), ô tick điều khoản (AC5–AC10), TrustCard
/// (AC16b). Task adhoc-20261003-login-medication-ui-fixes.
void main() {
  late InMemoryAuthRepository repo;
  late AuthController auth;

  setUp(() {
    repo = InMemoryAuthRepository(simulatedDelay: Duration.zero);
    auth = AuthController(repo);
  });

  /// Màn đăng nhập có AuthController, route thật của app (văn bản, OTP).
  Future<void> pumpLogin(WidgetTester tester, {bool selectEmail = true}) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AuthScope(controller: auth, child: child!),
      onGenerateRoute: onGenerateRoute,
      home: const LoginMobileScreen(),
    ));
    await tester.pumpAndSettle();
    if (selectEmail) {
      await tester.tap(find.text('Email').first);
      await tester.pumpAndSettle();
    }
  }

  final termsCheckbox = find.byKey(const Key('terms-checkbox'));
  final termsError = find.byKey(const Key('terms-error'));
  const consentErrorText =
      'Vui lòng đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư';

  final emailField = find.descendant(
      of: find.byType(EmailInputField), matching: find.byType(TextField));

  bool checked(WidgetTester tester) =>
      tester.widget<Checkbox>(termsCheckbox).value!;

  Future<void> tapSendOtp(WidgetTester tester) async {
    await tester.pump();
    await tester.ensureVisible(find.text('Nhận mã OTP'));
    await tester.tap(find.text('Nhận mã OTP'));
    await tester.pumpAndSettle();
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.ensureVisible(termsCheckbox);
    await tester.tap(termsCheckbox);
    await tester.pumpAndSettle();
  }

  Future<void> tapLink(WidgetTester tester, String text) async {
    await tester.ensureVisible(termsCheckbox);
    await tester.tapOnText(find.textRange.ofSubstring(text));
    await tester.pumpAndSettle();
  }

  testWidgets('AC11: mặc định SĐT, không thể gửi SMS, chuyển được sang Email',
      (tester) async {
    await pumpLogin(tester, selectEmail: false);
    final picker = find.byType(LoginSegmentedPicker);
    expect(tester.widget<LoginSegmentedPicker>(picker).selectedMethod,
        LoginMethod.phone);
    expect(find.textContaining('số điện thoại chưa được hỗ trợ'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Nhận mã OTP'))
            .onPressed,
        isNull);
    expect(repo.requestedPhoneOtps, isEmpty);
    await tester.tap(find.text('Email').first);
    await tester.pumpAndSettle();
    expect(tester.widget<LoginSegmentedPicker>(picker).selectedMethod,
        LoginMethod.email);
    expect(emailField, findsOneWidget);
  });

  testWidgets('AC13: ô nhập rộng bằng nút, sheet bo góc và icon Lucide',
      (tester) async {
    await pumpLogin(tester, selectEmail: false);
    final button = find.widgetWithText(FilledButton, 'Nhận mã OTP');
    final phone = find.byType(PhoneInputField);
    expect(tester.getSize(phone).width, tester.getSize(button).width);
    expect(find.byIcon(LucideIcons.phone), findsOneWidget);
    expect(find.byIcon(LucideIcons.mail), findsOneWidget);
    expect(find.text('Dùng email'), findsNothing);
    final sheet = find.byWidgetPredicate((widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).borderRadius ==
            const BorderRadius.vertical(top: Radius.circular(32)));
    expect(sheet, findsOneWidget);

    await tester.tap(find.text('Email').first);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(EmailInputField)).width,
        tester.getSize(button).width);
  });

  testWidgets('AC4: email không hợp lệ không gọi API', (tester) async {
    await pumpLogin(tester);
    await tick(tester);
    await tester.enterText(emailField, 'abc');
    await tapSendOtp(tester);
    expect(find.text('Địa chỉ email không đúng định dạng'), findsOneWidget);
    expect(repo.requestedEmailOtps, isEmpty);
  });

  group('ô tick điều khoản', () {
    testWidgets('AC5: có đúng một ô tick, mặc định chưa tick', (tester) async {
      await pumpLogin(tester);

      expect(find.byType(Checkbox), findsOneWidget);
      expect(checked(tester), isFalse);
    });

    testWidgets(
        'AC6: email hợp lệ, chưa tick → không gửi OTP, có lỗi yêu cầu đồng ý',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(emailField, 'lan@example.com');

      await tapSendOtp(tester);

      expect(repo.requestedEmailOtps, isEmpty);
      expect(find.byType(EmailOtpScreen), findsNothing);
      expect(termsError, findsOneWidget);
      expect(find.text(consentErrorText), findsOneWidget);
    });

    testWidgets('AC7: đã tick → gửi OTP một lần và sang màn OTP',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(emailField, 'lan@example.com');
      await tick(tester);

      await tapSendOtp(tester);

      expect(repo.requestedEmailOtps, ['lan@example.com']);
      expect(find.byType(EmailOtpScreen), findsOneWidget);
      expect(auth.termsAccepted, isTrue);
    });

    testWidgets(
        'bố cục: ô tick thẳng mép trái ô nhập, dòng lỗi căn giữa và cỡ chữ bằng dòng đồng ý',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(emailField, 'lan@example.com');
      await tapSendOtp(tester);

      final field = tester.getRect(find.byType(EmailInputField));
      final box = tester.getRect(termsCheckbox);
      // Ô vuông 18px nằm giữa vùng Checkbox; mép ô vuông lệch mép ô nhập không quá 4px.
      final squareLeft = box.center.dx - 9;
      expect((squareLeft - field.left).abs(), lessThanOrEqualTo(4));

      final error = tester.widget<Text>(termsError);
      expect(error.textAlign, TextAlign.center);
      final errorRect = tester.getRect(termsError);
      expect(errorRect.width, closeTo(field.width, 1));
      expect(errorRect.center.dx, closeTo(field.center.dx, 1));
      final agreement = tester.widget<Text>(find.descendant(
        of: find.byType(TermsAgreementRow),
        matching:
            find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      ));
      expect(error.style?.fontSize, agreement.textSpan!.style?.fontSize);
    });

    testWidgets(
        'chạm khoảng trống cạnh ô tick cũng đổi trạng thái (cả dòng là vùng chạm)',
        (tester) async {
      await pumpLogin(tester);
      final row = find.byType(TermsAgreementRow);
      await tester.ensureVisible(row);
      final box = tester.getRect(termsCheckbox);

      await tester.tapAt(Offset(box.right + 4, box.center.dy));
      await tester.pumpAndSettle();

      expect(checked(tester), isTrue);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    });

    testWidgets('tick sau khi báo lỗi thì lỗi biến mất', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(emailField, 'lan@example.com');
      await tapSendOtp(tester);
      expect(termsError, findsOneWidget);

      await tick(tester);

      expect(termsError, findsNothing);
    });

    for (final (link, title) in [
      ('Điều khoản dịch vụ', 'Điều khoản dịch vụ'),
      ('Chính sách quyền riêng tư', 'Chính sách quyền riêng tư'),
    ]) {
      testWidgets(
          'AC8: bấm "$link" mở văn bản có phiên bản; quay lại giữ tick và email',
          (tester) async {
        await pumpLogin(tester);
        await tester.enterText(emailField, 'lan@example.com');
        await tick(tester);

        await tapLink(tester, link);

        expect(find.byType(LegalDocumentScreen), findsOneWidget);
        expect(find.widgetWithText(AppBar, title), findsOneWidget);
        expect(find.textContaining('Phiên bản 2026-10-v1'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(LoginMobileScreen), findsOneWidget);
        expect(checked(tester), isTrue);
        expect(find.text('lan@example.com'), findsOneWidget);
      });
    }

    testWidgets('đổi qua SĐT rồi về Email vẫn giữ điều khoản', (tester) async {
      await pumpLogin(tester);
      await tick(tester);
      await tester.ensureVisible(find.text('Số điện thoại'));
      await tester.tap(find.text('Số điện thoại'));
      await tester.pumpAndSettle();
      expect(checked(tester), isTrue);
      await tester.tap(find.text('Email').first);
      await tester.pumpAndSettle();
      expect(checked(tester), isTrue);
    });

    testWidgets('AC10: chạm chữ thường đổi tick; chạm link không đổi',
        (tester) async {
      await pumpLogin(tester);
      await tester.ensureVisible(termsCheckbox);

      await tester.tapOnText(find.textRange.ofSubstring('Tôi đồng ý với'));
      await tester.pumpAndSettle();
      expect(checked(tester), isTrue);

      await tester.tapOnText(find.textRange.ofSubstring('Tôi đồng ý với'));
      await tester.pumpAndSettle();
      expect(checked(tester), isFalse);

      await tapLink(tester, 'Điều khoản dịch vụ');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(checked(tester), isFalse);
    });

    testWidgets('chạy độc lập (không có AuthScope): chưa tick vẫn chặn gửi OTP',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final submitted = <String>[];
      await tester.pumpWidget(MaterialApp(
        home:
            LoginMobileScreen(onSubmitOtp: (id, _) async => submitted.add(id)),
      ));
      await tester.tap(find.text('Email').first);
      await tester.pumpAndSettle();
      await tester.enterText(emailField, 'lan@example.com');

      await tapSendOtp(tester);
      expect(submitted, isEmpty);
      expect(termsError, findsOneWidget);

      await tick(tester);
      await tapSendOtp(tester);
      expect(submitted, ['lan@example.com']);
    });
  });

  testWidgets('giao diện không hứa quá mức về bảo mật', (tester) async {
    await pumpLogin(tester);

    expect(find.textContaining('mã hóa đầu cuối'), findsNothing);
    expect(find.textContaining('không bao giờ chia sẻ với bên thứ ba'),
        findsNothing);
  });
}
