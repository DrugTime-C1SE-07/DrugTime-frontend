import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/login_method.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/login_hero.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/otp_header.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/otp_pin_input.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/otp_resend_row.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/pill_sky_scene.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task adhoc-20261115-pill-mascot-redesign: màn xác thực OTP (AC13–AC17).
void main() {
  late InMemoryAuthRepository repo;
  late AuthController auth;

  setUp(() async {
    repo = InMemoryAuthRepository(simulatedDelay: Duration.zero);
    auth = AuthController(repo)..setMethod(LoginMethod.email);
    await auth.requestOtp('lan@example.com');
  });

  void setScreen(WidgetTester tester, [Size size = const Size(390, 844)]) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  MascotController mascot(WidgetTester tester) => tester
      .widget<MascotView>(find.byType(MascotView, skipOffstage: false))
      .controller;

  Finder pinField() => find.descendant(
      of: find.byType(OtpPinInput), matching: find.byType(TextField));

  /// Màn OTP email; [verified] ghi lại lần xác thực thành công thay cho điều hướng.
  Future<List<int>> pumpOtp(WidgetTester tester) async {
    final verified = <int>[];
    await tester.pumpWidget(AuthScope(
      controller: auth,
      child: MaterialApp(
        home: OtpVerificationScreen.email(
          email: 'lan@example.com',
          onVerifySuccess: () => verified.add(1),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return verified;
  }

  testWidgets('AC13: phần đầu mới, đủ thành phần, thanh trạng thái icon tối',
      (tester) async {
    setScreen(tester);
    reduceMotion(tester);
    await pumpOtp(tester);

    expect(find.byType(LoginHero), findsOneWidget);
    expect(find.byType(MascotView), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PillSkyScenePainter),
        findsOneWidget);
    expect(find.byKey(const Key('login-wordmark')), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w is AnnotatedRegion<SystemUiOverlayStyle> &&
            w.value == SystemUiOverlayStyle.dark),
        findsOneWidget);
    expect(find.byType(OtpHeader), findsOneWidget);
    expect(find.byType(OtpPinInput), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(OtpResendRow), matching: find.text('01:00')),
        findsOneWidget);
    expect(find.text('Đổi email'), findsOneWidget);
    expect(find.bySemanticsLabel('Quay lại màn hình trước'), findsOneWidget);
    // ô mã tự focus khi mở màn (autofocus có sẵn) → linh vật che mắt ngay
    expect(mascot(tester).mood, MascotMood.cover);
  });

  testWidgets('AC13: màn 360x640, chữ ×1.5 không tràn bố cục', (tester) async {
    setScreen(tester, const Size(360, 640));
    reduceMotion(tester);
    await tester.pumpWidget(AuthScope(
      controller: auth,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const OtpVerificationScreen.email(email: 'lan@example.com'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AC14: focus → che mắt; gõ → hé mắt rồi che lại; bỏ focus → đứng chờ',
      (tester) async {
    setScreen(tester);
    reduceMotion(tester);
    await pumpOtp(tester);

    await tester.tap(pinField());
    await tester.pump();
    expect(mascot(tester).mood, MascotMood.cover);

    await tester.enterText(pinField(), '1');
    await tester.pump();
    expect(mascot(tester).peek, isTrue);
    await tester.pump(const Duration(milliseconds: 800));
    expect(mascot(tester).peek, isFalse);
    expect(mascot(tester).mood, MascotMood.cover);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(mascot(tester).mood, MascotMood.idle);
  });

  // Nhánh "thiếu số" của _handleVerify không đi tới được bằng giao diện: nút "Xác nhận"
  // chỉ hiện khi đang có lỗi, và gõ/xóa ký tự là xóa lỗi (hành vi có sẵn).
  testWidgets(
      'AC15: bấm "Xác nhận" lại sau mã sai → vẫn lỗi, không chuyển tiếp, lo lắng',
      (tester) async {
    setScreen(tester);
    reduceMotion(tester);
    final verified = await pumpOtp(tester);

    // Mã sai lần đầu để hiện nút "Xác nhận" (nút chỉ hiện sau khi có lỗi).
    await tester.enterText(pinField(), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận'), findsOneWidget);
    expect(mascot(tester).mood, MascotMood.concerned);

    mascot(tester).play(MascotMood.idle);
    await tester.ensureVisible(find.text('Xác nhận'));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    expect(verified, isEmpty);
    expect(find.text('Xác nhận'), findsOneWidget);
    expect(mascot(tester).mood, MascotMood.concerned);
  });

  testWidgets('AC15: mã sai từ máy chủ → thông báo lỗi và lo lắng',
      (tester) async {
    setScreen(tester);
    reduceMotion(tester);
    final verified = await pumpOtp(tester);

    await tester.enterText(pinField(), '000000');
    await tester.pumpAndSettle();

    expect(verified, isEmpty);
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(OtpVerificationScreen),
            matching: find.byWidgetPredicate((w) =>
                w is Text &&
                w.style?.color != null &&
                w.data != null &&
                w.data!.isNotEmpty &&
                w.data == auth.errorMessage)),
        findsOneWidget);
    expect(mascot(tester).mood, MascotMood.concerned);
  });

  testWidgets('AC16: mã đúng → ăn mừng, SnackBar thành công, chuyển tiếp',
      (tester) async {
    setScreen(tester);
    reduceMotion(tester);
    final verified = await pumpOtp(tester);

    await tester.enterText(pinField(), '123456');
    await tester.pumpAndSettle();

    expect(mascot(tester).mood, MascotMood.celebrate);
    expect(find.text('Xác thực OTP thành công!'), findsOneWidget);
    expect(verified, [1]);
  });

  testWidgets('AC17: giảm chuyển động → không còn khung hình liên tục',
      (tester) async {
    setScreen(tester);
    reduceMotion(tester);
    await pumpOtp(tester);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('AC17: rời màn OTP thì ticker của nền và linh vật dừng',
      (tester) async {
    setScreen(tester);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(AuthScope(
      controller: auth,
      child: MaterialApp(
        navigatorKey: nav,
        home: const OtpVerificationScreen.email(email: 'lan@example.com'),
      ),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.hasScheduledFrame, isTrue);

    nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
