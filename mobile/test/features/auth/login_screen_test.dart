import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/phone_otp_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/legal_document_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/widgets/terms_agreement_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  Future<void> pumpLogin(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AuthScope(controller: auth, child: child!),
      onGenerateRoute: onGenerateRoute,
      home: const LoginMobileScreen(),
    ));
    await tester.pumpAndSettle();
  }

  final helperRow = find.byKey(const Key('login-helper-row'));
  final termsCheckbox = find.byKey(const Key('terms-checkbox'));
  final termsError = find.byKey(const Key('terms-error'));
  const consentErrorText = 'Vui lòng đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư';

  // AnimatedCrossFade đặt ô đang ẩn (email) trước trong cây, nên tìm ô SĐT qua PhoneInputField.
  final phoneField =
      find.descendant(of: find.byType(PhoneInputField), matching: find.byType(TextField));

  bool checked(WidgetTester tester) => tester.widget<Checkbox>(termsCheckbox).value!;

  Future<void> tapSendOtp(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Gửi mã OTP'));
    await tester.tap(find.text('Gửi mã OTP'));
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

  group('dòng phụ trợ dưới ô nhập', () {
    testWidgets('AC1: tab SĐT dùng icon SMS Material, không còn MessageCircleIcon', (tester) async {
      await pumpLogin(tester);

      expect(
        find.descendant(of: helperRow, matching: find.byIcon(Icons.sms_outlined)),
        findsOneWidget,
      );
      expect(find.text('Mã OTP sẽ được gửi qua tin nhắn SMS'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == 'MessageCircleIcon'),
        findsNothing,
      );
    });

    testWidgets('AC2: tab Email dùng icon thư, câu chữ giữ nguyên', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text('Email').first);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: helperRow, matching: find.byIcon(Icons.mail_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: helperRow, matching: find.byIcon(Icons.sms_outlined)),
        findsNothing,
      );
      expect(find.text('Mã OTP sẽ được gửi qua hòm thư điện tử'), findsOneWidget);
    });

    testWidgets('AC4: cỡ chữ 2.0, dòng phụ trợ đủ cao, không bị cắt', (tester) async {
      await pumpLogin(tester, textScale: 2.0);

      final paragraph =
          tester.renderObject<RenderParagraph>(find.text('Mã OTP sẽ được gửi qua tin nhắn SMS'));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(paragraph.size.width)),
      );
      expect(tester.getSize(helperRow).height, greaterThanOrEqualTo(paragraph.size.height));
      expect(tester.takeException(), isNull);
    });
  });

  group('ô tick điều khoản', () {
    testWidgets('AC5: có đúng một ô tick, mặc định chưa tick', (tester) async {
      await pumpLogin(tester);

      expect(find.byType(Checkbox), findsOneWidget);
      expect(checked(tester), isFalse);
    });

    testWidgets('AC6: SĐT hợp lệ, chưa tick → không gửi OTP, có lỗi yêu cầu đồng ý',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(phoneField, '0900000001');

      await tapSendOtp(tester);

      expect(repo.requestedPhoneOtps, isEmpty);
      expect(find.byType(PhoneOtpScreen), findsNothing);
      expect(termsError, findsOneWidget);
      expect(find.text(consentErrorText), findsOneWidget);
    });

    testWidgets('AC7: đã tick → gửi OTP một lần và sang màn OTP', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(phoneField, '0900000001');
      await tick(tester);

      await tapSendOtp(tester);

      expect(repo.requestedPhoneOtps, ['+84900000001']);
      expect(find.byType(PhoneOtpScreen), findsOneWidget);
      expect(auth.termsAccepted, isTrue);
    });

    testWidgets('bố cục: ô tick thẳng mép trái ô nhập, dòng lỗi căn giữa và cỡ chữ bằng dòng đồng ý',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(phoneField, '0900000001');
      await tapSendOtp(tester);

      final field = tester.getRect(find.byType(PhoneInputField));
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
        matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      ));
      expect(error.style?.fontSize, agreement.textSpan!.style?.fontSize);
    });

    testWidgets('chạm khoảng trống cạnh ô tick cũng đổi trạng thái (cả dòng là vùng chạm)',
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
      await tester.enterText(phoneField, '0900000001');
      await tapSendOtp(tester);
      expect(termsError, findsOneWidget);

      await tick(tester);

      expect(termsError, findsNothing);
    });

    for (final (link, title) in [
      ('Điều khoản dịch vụ', 'Điều khoản dịch vụ'),
      ('Chính sách quyền riêng tư', 'Chính sách quyền riêng tư'),
    ]) {
      testWidgets('AC8: bấm "$link" mở văn bản có phiên bản; quay lại giữ tick và số',
          (tester) async {
        await pumpLogin(tester);
        await tester.enterText(phoneField, '0900000001');
        await tick(tester);

        await tapLink(tester, link);

        expect(find.byType(LegalDocumentScreen), findsOneWidget);
        expect(find.widgetWithText(AppBar, title), findsOneWidget);
        expect(find.textContaining('Phiên bản 2026-10-v1'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(LoginMobileScreen), findsOneWidget);
        expect(checked(tester), isTrue);
        expect(find.text('090 000 0001'), findsOneWidget);
      });
    }

    testWidgets('AC9: đổi tab Email rồi quay lại vẫn tick', (tester) async {
      await pumpLogin(tester);
      await tick(tester);

      await tester.tap(find.text('Email').first);
      await tester.pumpAndSettle();
      expect(checked(tester), isTrue);
      await tester.tap(find.text('Số điện thoại').first);
      await tester.pumpAndSettle();

      expect(checked(tester), isTrue);
    });

    testWidgets('AC10: chạm chữ thường đổi tick; chạm link không đổi', (tester) async {
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

    testWidgets('chạy độc lập (không có AuthScope): chưa tick vẫn chặn gửi OTP', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final submitted = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: LoginMobileScreen(onSubmitOtp: (id, _) async => submitted.add(id)),
      ));
      await tester.enterText(phoneField, '0900000001');

      await tapSendOtp(tester);
      expect(submitted, isEmpty);
      expect(termsError, findsOneWidget);

      await tick(tester);
      await tapSendOtp(tester);
      expect(submitted, ['090 000 0001']);
    });
  });

  testWidgets('AC16b: TrustCard không còn câu hứa sai', (tester) async {
    await pumpLogin(tester);

    expect(find.textContaining('mã hóa đầu cuối'), findsNothing);
    expect(find.textContaining('không bao giờ chia sẻ với bên thứ ba'), findsNothing);
    expect(find.text('Dữ liệu được truyền qua kết nối mã hóa.'), findsOneWidget);
    expect(find.text('Chỉ người thân bạn cho phép mới xem được dữ liệu của bạn.'), findsOneWidget);
  });
}
