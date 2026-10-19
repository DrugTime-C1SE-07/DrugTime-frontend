// E2E pha 3 (AC20 phần hồ sơ). Trước pha này script điều phối đặt hồ sơ của số thử về NULL
// (giữ consent); sau pha, script kiểm `users.full_name` đúng nguyên văn chuỗi injection và bảng
// `users` vẫn còn.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

const injectionName = "'); DROP TABLE users;--";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AC20: họ tên rỗng → báo lỗi tại chỗ; họ tên là chuỗi injection → lưu, vào Trang chủ',
      (tester) async {
    await clearSession();
    await startApp(tester);

    await loginWithPhone(tester);
    await waitFor(tester, profileScreen);
    await pickBirthDate(tester);
    await selectGender(tester, 'Nữ');
    await submitProfile(tester);
    await waitFor(tester, find.byKey(const Key('profile-error')));
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-error'))).data,
      'Vui lòng nhập họ tên',
    );
    expect(profileScreen, findsOneWidget);

    await enterFullName(tester, injectionName);
    await submitProfile(tester);
    await waitFor(tester, homeShell);
    await logout(tester);
  });
}
