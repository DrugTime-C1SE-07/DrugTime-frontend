import 'package:drugtime_mobile/core/widgets/home_indicator.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/otp_resend_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/floating_pills.dart';
import 'package:drugtime_mobile/core/widgets/status_bar_compact.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Màn Đăng nhập và Xác thực OTP dùng status bar và thanh điều hướng của hệ điều hành,
/// không tự vẽ bản giả (giờ "09:41", sóng, pin, home indicator kiểu iOS).
const _statusBarHeight = 48.0;
const _navigationBarHeight = 24.0;

final _screens = <String, Widget Function({bool enableFramePreview})>{
  'Đăng nhập': ({bool enableFramePreview = false}) =>
      LoginMobileScreen(enableFramePreview: enableFramePreview),
  'Xác thực OTP': ({bool enableFramePreview = false}) =>
      OtpVerificationScreen.email(
        email: 'lan@example.com',
        enableFramePreview: enableFramePreview,
      ),
};

void _setScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  const insets =
      FakeViewPadding(top: _statusBarHeight, bottom: _navigationBarHeight);
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  addTearDown(tester.view.reset);
}

Finder _frameMockup() => find.byWidgetPredicate(
      (widget) =>
          (widget is Container &&
              widget.constraints?.maxWidth == 375.0 &&
              widget.constraints?.maxHeight == 812.0) ||
          (widget is SizedBox && widget.width == 375 && widget.height == 812),
    );

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
}

/// Gỡ cây widget để hủy bộ đếm gửi lại mã của màn OTP.
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('sheet đăng nhập phủ tới đáy vùng an toàn', (tester) async {
    _setScreen(tester, const Size(375, 1000));
    await _pump(tester, const LoginMobileScreen());
    final sheet = find.byKey(const Key('login-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getBottomLeft(sheet).dy, closeTo(976, 0.1));
    await _unmount(tester);
  });

  testWidgets('AC12: login animation settles when reduced motion is enabled',
      (tester) async {
    _setScreen(tester, const Size(375, 812));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, const LoginMobileScreen());
    expect(find.byType(FloatingPills), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await _unmount(tester);
  });

  testWidgets('AC13: bộ đếm OTP màu xanh, icon Lucide và sheet bo góc',
      (tester) async {
    _setScreen(tester, const Size(375, 812));
    await _pump(
        tester, const OtpVerificationScreen.email(email: 'lan@example.com'));
    expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    final seconds = find.descendant(
        of: find.byType(OtpResendRow), matching: find.text('01:00'));
    expect(tester.widget<Text>(seconds).style?.color, AppColors.brand);
    final sheet = find.byWidgetPredicate((widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).borderRadius ==
            const BorderRadius.vertical(top: Radius.circular(32)));
    expect(sheet, findsOneWidget);
    await _unmount(tester);
  });

  for (final entry in _screens.entries) {
    final name = entry.key;
    final build = entry.value;

    group(name, () {
      testWidgets('không vẽ status bar và home indicator giả', (tester) async {
        _setScreen(tester, const Size(412, 915));
        await _pump(tester, build());

        expect(find.text('09:41'), findsNothing);
        expect(find.byType(StatusBarCompact), findsNothing);
        expect(find.byType(HomeIndicator), findsNothing);
        await _unmount(tester);
      });

      testWidgets(
          'nội dung nằm giữa status bar và thanh điều hướng của hệ điều hành',
          (tester) async {
        _setScreen(tester, const Size(412, 915));
        await _pump(tester, build());

        final content = find.byType(SingleChildScrollView);
        expect(tester.getTopLeft(content).dy,
            greaterThanOrEqualTo(_statusBarHeight));
        expect(
          tester.getBottomLeft(content).dy,
          lessThanOrEqualTo(915 - _navigationBarHeight),
        );
        await _unmount(tester);
      });

      testWidgets('icon status bar màu sáng trên nền xanh', (tester) async {
        _setScreen(tester, const Size(412, 915));
        await _pump(tester, build());

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnnotatedRegion<SystemUiOverlayStyle> &&
                widget.value == SystemUiOverlayStyle.light,
          ),
          findsOneWidget,
        );
        await _unmount(tester);
      });

      testWidgets('màn rộng không tự chuyển sang khung mockup 375x812',
          (tester) async {
        _setScreen(tester, const Size(800, 1000));
        await _pump(tester, build());

        expect(_frameMockup(), findsNothing);
        await _unmount(tester);
      });

      testWidgets('khung mockup chỉ hiện khi bật enableFramePreview',
          (tester) async {
        _setScreen(tester, const Size(800, 1000));
        await _pump(tester, build(enableFramePreview: true));

        expect(_frameMockup(), findsOneWidget);
        await _unmount(tester);
      });
    });
  }
}
