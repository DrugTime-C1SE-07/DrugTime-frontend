// E2E pha 2 (AC19, AC20 phần số điện thoại). Số thử đã có hồ sơ và consent từ pha 1; sau pha,
// script kiểm vẫn chỉ có một dòng `users` cho số thử, cùng `user_id` với pha 1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AC19: OTP sai → báo lỗi, ở lại màn OTP; nhập lại mã đúng → Trang chủ',
      (tester) async {
    await clearSession();
    await startApp(tester);

    await submitPhone(tester, testPhone);
    await enterOtp(tester, wrongOtp);
    await waitFor(tester, find.text('Mã OTP không đúng hoặc đã hết hạn'));
    expect(otpScreen, findsOneWidget);
    expect(homeShell, findsNothing);

    await enterOtp(tester, testPhoneOtp);
    await waitFor(tester, homeShell);
    await logout(tester);
  });

  testWidgets('AC20: số sai không gửi OTP; số có khoảng trắng vẫn đăng nhập được',
      (tester) async {
    await clearSession();
    await startApp(tester);

    // Ô nhập chỉ nhận chữ số (FilteringTextInputFormatter.digitsOnly): "abc" thành rỗng.
    await submitPhone(tester, 'abc');
    await waitFor(tester, find.text('Vui lòng nhập số điện thoại'));
    expect(otpScreen, findsNothing);

    await submitPhone(tester, '12');
    await waitFor(tester, find.text('Số điện thoại không hợp lệ (9-11 chữ số)'));
    expect(otpScreen, findsNothing);

    // Cách lần gửi OTP ở test trước ít nhất 5 giây (giới hạn của Supabase local).
    await pumpFor(tester, otpResendGap);
    await submitPhone(tester, '0900 000 001');
    final field = tester.widget<TextField>(
      find.descendant(of: loginScreen, matching: find.byType(TextField)).first,
    );
    expect(field.controller?.text, '0900000001');
    await enterOtp(tester, testPhoneOtp);
    await waitFor(tester, homeShell);
    await logout(tester);
  });
}
