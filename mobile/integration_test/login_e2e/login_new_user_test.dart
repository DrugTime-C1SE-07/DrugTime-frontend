// E2E pha 1 (AC16–AC18). Trước pha này script điều phối đặt hồ sơ của số thử về NULL và rút
// consent `health_data`; sau pha, script kiểm `users.full_name` và `phone_number` trong DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'AC16–AC18: chưa có hồ sơ → hồ sơ → consent → Trang chủ; mở lại vẫn vào; đăng xuất',
      (tester) async {
    await clearSession();
    await startApp(tester);

    // AC16: đăng nhập bằng số thử, hoàn thiện hồ sơ, đồng ý consent, vào Trang chủ.
    await loginWithPhone(tester);
    expect(profileScreen, findsOneWidget);
    await enterFullName(tester, 'Nguyễn Văn Ấn');
    await pickBirthDate(tester);
    await selectGender(tester, 'Nam');
    await submitProfile(tester);
    await acceptConsent(tester);
    await waitFor(tester, homeShell);

    // AC17: mở lại app với cùng bộ nhớ thiết bị → vào thẳng Trang chủ, không hỏi OTP.
    await startApp(tester);
    await waitFor(tester, homeShell);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(homeShell, findsOneWidget);
    expect(loginScreen, findsNothing);
    expect(otpScreen, findsNothing);

    // AC18: đăng xuất → màn Đăng nhập; mở lại app vẫn ở màn Đăng nhập.
    await logout(tester);
    await startApp(tester);
    await waitFor(tester, loginScreen);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(loginScreen, findsOneWidget);
    expect(homeShell, findsNothing);
  });
}
