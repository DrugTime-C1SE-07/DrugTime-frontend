import 'package:drugtime_mobile/features/auth/domain/entities/login_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AC5, AC7: email sai, đổi email, gửi lại và xác thực',
      (tester) async {
    await clearSession();
    await startApp(tester);
    final inbox = EmailOtpInbox();
    await inbox.snapshot();

    await submitEmail(tester, 'email-sai');
    await waitFor(tester, find.text('Địa chỉ email không đúng định dạng'));
    expect(otpScreen, findsNothing);

    await submitEmail(tester, testEmail);
    await waitFor(tester, otpScreen);
    final masked = AuthValidator.maskEmail(testEmail);
    expect(find.textContaining(masked, findRichText: true), findsOneWidget);

    await inbox.nextCode(tester);
    await tapVisible(tester, find.text('Đổi email'));
    await waitFor(tester, loginScreen);
    final field =
        find.descendant(of: loginScreen, matching: find.byType(TextField));
    if (tester.widget<TextField>(field).controller?.text != testEmail) {
      fail('Đổi email không giữ giá trị trước đó.');
    }
    // Supabase local rate-limits the same email for one second.
    await pumpFor(tester, const Duration(seconds: 1));
    await tapVisible(tester, find.text('Nhận mã OTP'));
    await waitFor(tester, otpScreen);
    await inbox.nextCode(tester);
    expect(find.text('Gửi lại mã'), findsNothing);
    await waitFor(tester, find.text('Gửi lại mã'),
        timeout: const Duration(seconds: 65));
    await inbox.snapshot();
    await tapVisible(tester, find.text('Gửi lại mã'));
    final otp = await inbox.nextCode(tester);
    await enterOtp(tester, otp == wrongOtp ? '111111' : wrongOtp);
    await waitFor(tester, find.text('Mã OTP không đúng hoặc đã hết hạn'));
    expect(homeShell, findsNothing);

    await enterOtp(tester, otp);
    await waitFor(tester, homeShell);
    await logout(tester);
  });
}
