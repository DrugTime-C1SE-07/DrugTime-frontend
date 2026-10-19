// Helper dùng chung cho test E2E đăng nhập: app thật (lib/main.dart) gọi backend thật.
//
// Chạy qua script điều phối `tests/e2e/mobile_login/run_e2e.py` (khởi động backend, chuẩn bị và
// đối chiếu dữ liệu trong DB). Base URL truyền bằng
// `--dart-define=DRUGTIME_API_BASE_URL=http://10.0.2.2:<cổng>`.
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_session_store.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/consent_screen.dart';
import 'package:drugtime_mobile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Số thử `test_otp` của Supabase local (`backend/supabase/config.toml`): không gửi SMS thật.
const testPhone = '0900000001';
const testPhoneOtp = '123456';
const wrongOtp = '000000';

/// Supabase local chặn gửi OTP lại cho cùng một số trong 5 giây (`max_frequency`).
const otpResendGap = Duration(seconds: 6);

const _step = Duration(milliseconds: 100);
const _defaultTimeout = Duration(seconds: 20);

final loginScreen = find.byType(LoginMobileScreen);
final otpScreen = find.byType(OtpVerificationScreen);
final profileScreen = find.byType(CompleteProfileScreen);
final consentScreen = find.byType(ConsentScreen);
final homeShell = find.byType(AppShell);

/// Xóa phiên đã lưu trên thiết bị: dữ liệu app còn lại giữa các lần `flutter test`.
Future<void> clearSession() => SecureAuthSessionStore().clear();

/// Mở app bằng `main()` thật (lặp lại được để giả lập mở lại app với cùng bộ nhớ thiết bị).
///
/// Tháo cây widget cũ trước: nếu gọi `runApp` lần hai với cùng kiểu widget gốc, Flutter giữ State
/// cũ (không chạy lại `initState`), app không đọc lại phiên đã lưu và vẫn nghe AuthController cũ.
Future<void> startApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  app.main();
  await tester.pump();
}

/// Pump tới khi [finder] xuất hiện. Không dùng `pumpAndSettle` vì app thật có timer chạy nền
/// (kiểm tra kết nối, vòng xoay) nên không bao giờ "settle".
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = _defaultTimeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(_step);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Hết ${timeout.inSeconds} giây mà chưa thấy: ${finder.describeMatch(Plurality.zero)}. '
      'Đang hiển thị: ${_visibleScreens()}. Chữ trên màn: ${_visibleTexts()}');
}

/// Tối đa 20 chuỗi chữ đang hiển thị (bỏ trùng), để đọc được thông báo lỗi thực tế khi hết giờ chờ.
String _visibleTexts() {
  final texts = <String>{
    for (final element in find.byType(Text).hitTestable().evaluate())
      if ((element.widget as Text).data case final data? when data.trim().isNotEmpty) data.trim(),
  };
  return texts.take(20).map((t) => '"$t"').join(', ');
}

/// Tên các màn chính đang có trên cây widget, để biết test kẹt ở đâu khi hết giờ chờ.
String _visibleScreens() {
  final screens = {
    'Đăng nhập': loginScreen,
    'OTP': otpScreen,
    'Hồ sơ': profileScreen,
    'Consent': consentScreen,
    'Trang chủ (AppShell)': homeShell,
    'Dialog': find.byType(Dialog),
  };
  final shown = [
    for (final entry in screens.entries)
      if (entry.value.evaluate().isNotEmpty) entry.key,
  ];
  return shown.isEmpty ? '(không có màn nào trong danh sách)' : shown.join(', ');
}

/// Pump trong [duration] để UI cập nhật mà không cần chờ một widget cụ thể.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(_step);
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(_step);
  await tester.tap(finder);
  await tester.pump(_step);
}

/// Nhập số điện thoại, tick điều khoản (nếu chưa), bấm "Gửi mã OTP". Không chờ màn OTP.
/// Gõ [text] vào ô [field] như người dùng.
///
/// Trên thiết bị, sau khi ô bị bỏ focus bằng code (gửi OTP, xác thực) rồi được dùng lại, kênh nhập
/// phím giả lập của integration_test có lúc không còn gắn vào ô và `enterText` không đổi được nội
/// dung (đã kiểm: ô giữ nguyên chữ cũ). Khi đó áp đúng `inputFormatters` của ô lên [text] rồi đặt
/// qua controller — app nghe controller nên phản ứng như khi gõ; việc gõ bằng bàn phím thật được
/// kiểm tay.
Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field, warnIfMissed: false);
  await tester.pump(_step);
  await tester.enterText(field, text);
  await tester.pump(_step);
  final widget = tester.widget<TextField>(field);
  var expected = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  for (final formatter in widget.inputFormatters ?? const <TextInputFormatter>[]) {
    expected = formatter.formatEditUpdate(TextEditingValue.empty, expected);
  }
  if (widget.controller!.text != expected.text) {
    widget.controller!.value = expected;
    await tester.pump(_step);
  }
}

Future<void> submitPhone(WidgetTester tester, String raw) async {
  await waitFor(tester, loginScreen);
  await typeInto(
    tester,
    find.descendant(of: find.byType(PhoneInputField), matching: find.byType(TextField)),
    raw,
  );
  final checkbox = find.byKey(const Key('terms-checkbox'));
  if (tester.widget<Checkbox>(checkbox).value != true) {
    await tapVisible(tester, checkbox);
  }
  await tapVisible(tester, find.text('Gửi mã OTP'));
}

/// Nhập mã như người dùng: xóa mã cũ rồi gõ mã mới. Đủ 6 số thì app tự gửi xác thực.
Future<void> enterOtp(WidgetTester tester, String code) async {
  await waitFor(tester, otpScreen);
  final field = find.descendant(of: otpScreen, matching: find.byType(TextField));
  await typeInto(tester, field, '');
  await typeInto(tester, field, code);
}

/// Đăng nhập trọn vẹn bằng số thử; dừng khi đã rời màn OTP (sang màn Hồ sơ hoặc Trang chủ).
Future<void> loginWithPhone(WidgetTester tester, {String raw = testPhone}) async {
  await submitPhone(tester, raw);
  await enterOtp(tester, testPhoneOtp);
  await waitFor(tester, find.byWidgetPredicate(
    (w) => w is CompleteProfileScreen || w is ConsentScreen || w is AppShell,
  ));
}

/// Màn consent hiện khi chưa đồng ý `health_data`: bật mục bắt buộc rồi bấm Tiếp tục.
Future<void> acceptConsent(WidgetTester tester) async {
  await waitFor(tester, consentScreen);
  final healthData = find.byKey(const Key('consent-switch-health_data'));
  if (!tester.widget<Switch>(healthData).value) {
    await tapVisible(tester, healthData);
  }
  await tapVisible(tester, find.byKey(const Key('consent-continue')));
}

Future<void> enterFullName(WidgetTester tester, String name) async {
  await waitFor(tester, profileScreen);
  await typeInto(tester, find.byKey(const Key('profile-full-name')), name);
}

/// Mở date picker và chọn ngày mặc định của app (năm hiện tại − 60).
Future<void> pickBirthDate(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('profile-date-of-birth')));
  await waitFor(tester, find.text('Chọn'));
  await tester.tap(find.text('Chọn'));
  await pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> selectGender(WidgetTester tester, String label) =>
    tapVisible(tester, find.descendant(of: profileScreen, matching: find.text(label)));

Future<void> submitProfile(WidgetTester tester) =>
    tapVisible(tester, find.byKey(const Key('profile-submit')));

/// Tab "Hồ sơ" → Đăng xuất; chờ về màn Đăng nhập.
Future<void> logout(WidgetTester tester) async {
  await waitFor(tester, homeShell);
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Hồ sơ')));
  await pumpFor(tester, const Duration(milliseconds: 500));
  await tapVisible(tester, find.byKey(const Key('logout-tile')));
  await waitFor(tester, loginScreen);
}
