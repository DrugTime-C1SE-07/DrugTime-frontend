import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/consent/data/account_deletion_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/account_deletion_screen.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_rig.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';

class FakeDeletion implements AccountDeletionRepository {
  PendingAccountDeletion? pending;
  int creates = 0, verifies = 0, cancellations = 0;
  Object? failure;
  Object? lookupFailure;
  DateTime? expiresAt;
  Completer<void>? verifyWait, cancelWait;
  @override
  Future<PendingAccountDeletion?> current() async {
    if (lookupFailure != null) throw lookupFailure!;
    return pending;
  }

  @override
  Future<DeletionChallenge> issue() async => DeletionChallenge(
      'challenge', expiresAt ?? DateTime.now().add(const Duration(minutes: 5)));
  @override
  Future<void> verify(String challenge, String otp) async {
    verifies++;
    if (verifyWait != null) await verifyWait!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<PendingAccountDeletion> create(String challenge) async {
    creates++;
    if (failure != null) throw failure!;
    return pending = PendingAccountDeletion(
        DateTime.utc(2026, 11, 19), DateTime.utc(2026, 12, 19));
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    if (cancelWait != null) await cancelWait!.future;
    if (failure != null) throw failure!;
    pending = null;
  }
}

const shot = Key('deletion-screenshot');
Future<AuthController> host(WidgetTester tester, FakeDeletion repo,
    {bool returning = false,
    VoidCallback? restored,
    double width = 375,
    double height = 812,
    DateTime Function()? clock}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final auth = AuthController(InMemoryAuthRepository(
      simulatedDelay: Duration.zero,
      initialSession: AuthSession(
          userId: 'u',
          accessToken: 'session',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          profileComplete: true)));
  await auth.initSession();
  await tester.pumpWidget(AuthScope(
      controller: auth,
      child: MaterialApp(
          theme: ThemeData(fontFamily: 'WelcomeInter', useMaterial3: true),
          home: RepaintBoundary(
              key: shot,
              child: AccountDeletionScreen(
                  repository: repo,
                  clock: clock,
                  pending: returning ? repo.pending : null,
                  onRestored: restored)))));
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  await tester.pump();
  return auth;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DELETION')) return;
  await tester.pump(const Duration(milliseconds: 300));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../output/account-deletion/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> openOtp(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('Tiếp tục'));
  await tester.pump();
  await tester.tap(find.text('Gửi mã'));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await MascotView.preloadFigmaArtwork();
    final loader = FontLoader('WelcomeInter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await loader.load();
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await icons.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
  });
  testWidgets(
      'real app routes Vẫn xóa back to login while keeping deletion request',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final saved = PendingAccountDeletion(
        DateTime.utc(2026, 11, 19), DateTime.utc(2026, 12, 19));
    final repo = FakeDeletion()..pending = saved;
    final auth = AuthController(InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
            userId: '00000000-0000-4000-8000-000000000001',
            accessToken: 'session',
            expiresAt: DateTime.now().add(const Duration(days: 1)),
            profileComplete: true)));
    await tester.pumpWidget(
        DrugTimeApp(authController: auth, accountDeletionRepository: repo));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Yêu cầu đang chờ xử lý'), findsOneWidget);
    await tester.tap(find.text('Vẫn xóa'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LoginMobileScreen), findsOneWidget);
    expect(repo.pending, same(saved));
    expect(repo.cancellations, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'X1 X1b X2 X3c X4 X6: verify never creates until final confirmation',
      (tester) async {
    final repo = FakeDeletion();
    await host(tester, repo);
    await capture(tester, 'X1');
    expect(find.text('Tải dữ liệu của tôi trước'), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Tiếp tục'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await capture(tester, 'X1b');
    expect(tester.getTopLeft(find.text('Tôi hiểu dữ liệu sẽ bị xóa')).dy,
        greaterThan(600));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await capture(tester, 'X2');
    await tester.tap(find.text('Gửi mã'));
    await tester.pump();
    await tester.pump();
    await capture(tester, 'X3a');
    repo.verifyWait = Completer<void>();
    await tester.enterText(find.byKey(const Key('deletion-otp')), '123456');
    await tester.pump();
    await capture(tester, 'X3c');
    expect(repo.creates, 0);
    expect(find.text('Đang xác thực…'), findsOneWidget);
    repo.verifyWait!.complete();
    await tester.pump();
    await tester.pump();
    await capture(tester, 'X4');
    expect(find.text('Xóa tài khoản này?'), findsOneWidget);
    expect(repo.creates, 0);
    await tester.tap(find.text('Xóa tài khoản'));
    await tester.pump();
    await tester.pump();
    await capture(tester, 'X6');
    expect(repo.creates, 1);
    expect(find.text('19/12/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('wrong OTP and backend lock retain retry in existing screens',
      (tester) async {
    final repo = FakeDeletion();
    await host(tester, repo);
    await openOtp(tester);
    repo.failure = const ApiException('{"detail":"deletion_otp_invalid"}',
        statusCode: 422, remainingOtpAttempts: 4);
    await tester.enterText(find.byKey(const Key('deletion-otp')), '123456');
    await tester.pump();
    await tester.pump();
    await capture(tester, 'X3d');
    expect(find.text('Mã không đúng · còn 4 lần thử'), findsOneWidget);
    repo.failure = const ApiException('{"detail":"deletion_otp_invalid"}',
        statusCode: 422,
        remainingOtpAttempts: 0,
        retryAfter: Duration(minutes: 15));
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump();
    await capture(tester, 'X3f');
    expect(find.text('Tạm dừng xác thực'), findsOneWidget);
    expect(repo.creates, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('backend verification lock stays locked during its final minute',
      (tester) async {
    final repo = FakeDeletion();
    await host(tester, repo);
    await openOtp(tester);
    repo.failure = const ApiException('{"detail":"deletion_otp_rate_limited"}',
        statusCode: 429, retryAfter: Duration(seconds: 45));
    await tester.enterText(find.byKey(const Key('deletion-otp')), '123456');
    await tester.pump();
    await tester.pump();
    expect(find.text('Tạm dừng xác thực'), findsOneWidget);
    expect(find.text('00:45'), findsOneWidget);
    expect(find.byKey(const Key('deletion-otp')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('X7 waits for backend cancel ACK; errors stay on X7',
      (tester) async {
    final repo = FakeDeletion()
      ..pending = PendingAccountDeletion(
          DateTime.utc(2026, 11, 19), DateTime.utc(2026, 12, 19));
    var restored = false;
    await host(tester, repo, returning: true, restored: () => restored = true);
    await capture(tester, 'X7');
    repo.cancelWait = Completer<void>();
    await tester.tap(find.text('Đăng nhập lại'));
    await tester.pump();
    expect(restored, isFalse);
    repo.failure = const ApiException('timeout', isTransient: true);
    repo.cancelWait!.complete();
    await tester.pump();
    await tester.pump();
    expect(restored, isFalse);
    expect(find.text('Yêu cầu đang chờ xử lý'), findsOneWidget);
    repo.failure = null;
    repo.cancelWait = null;
    await tester.tap(find.text('Đăng nhập lại'));
    await tester.pump();
    await tester.pump();
    expect(restored, isTrue);
    expect(repo.cancellations, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('X3e expires after five minutes and enables resend',
      (tester) async {
    var now = DateTime.utc(2026, 11, 19);
    final repo = FakeDeletion()
      ..expiresAt = now.add(const Duration(minutes: 5));
    await host(tester, repo, clock: () => now);
    await openOtp(tester);
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mã đã hết hạn'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Gửi lại mã'))
            .onPressed,
        isNotNull);
    await capture(tester, 'X3e');
    expect(repo.creates, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('OTP highlights current input and preserves Figma type scale',
      (tester) async {
    await host(tester, FakeDeletion());
    await openOtp(tester);
    await tester.enterText(find.byKey(const Key('deletion-otp')), '912');
    await tester.pump();
    // The input must not paint the theme's filled background over the digits.
    expect(
        find.ancestor(
            of: find.byKey(const Key('deletion-otp')),
            matching: find.byWidgetPredicate(
                (widget) => widget is Opacity && widget.opacity == 0)),
        findsOneWidget);
    BoxDecoration digit(int index) => tester
        .widget<Container>(find.byKey(ValueKey('deletion-digit-$index')))
        .decoration! as BoxDecoration;
    expect(digit(0).color, Colors.white);
    expect(digit(3).border!.top.color, const Color(0xff01554f));
    expect(digit(3).border!.top.width, 2);
    expect(digit(4).color, const Color(0xfff5f7f6));
    final subtitle = tester.widget<Text>(find.byWidgetPredicate((widget) =>
        widget is Text &&
        widget.textSpan?.toPlainText().startsWith('Mã 6 số đã gửi tới') ==
            true));
    expect(subtitle.style!.fontSize, 17);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('OTP digit boxes stay above the software keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await host(tester, FakeDeletion());
    await openOtp(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 6; i++) {
      final digit = tester.getRect(find.byKey(ValueKey('deletion-digit-$i')));
      expect(digit.top, greaterThanOrEqualTo(0));
      expect(digit.bottom, lessThanOrEqualTo(512));
      expect(digit.height, 60);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Vẫn xóa signs out without cancelling or changing deadline',
      (tester) async {
    final saved = PendingAccountDeletion(
        DateTime.utc(2026, 11, 19), DateTime.utc(2026, 12, 19));
    final repo = FakeDeletion()..pending = saved;
    final auth = await host(tester, repo, returning: true);
    await tester.tap(find.text('Vẫn xóa'));
    await tester.pump();
    await tester.pump();
    expect(auth.isAuthenticated, isFalse);
    expect(repo.cancellations, 0);
    expect(repo.pending, same(saved));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'login gate waits for explicit cancellation and fails closed on lookup error',
      (tester) async {
    final repo = FakeDeletion()
      ..pending = PendingAccountDeletion(
          DateTime.utc(2026, 11, 19), DateTime.utc(2026, 12, 19))
      ..lookupFailure = const ApiException('network');
    final auth = AuthController(InMemoryAuthRepository(
        initialSession: AuthSession(
            userId: 'u',
            accessToken: 'session',
            expiresAt: DateTime.now().add(const Duration(days: 1)),
            profileComplete: true),
        simulatedDelay: Duration.zero));
    await auth.initSession();
    await tester.pumpWidget(AuthScope(
        controller: auth,
        child: MaterialApp(
            home: AccountDeletionScope(
                repository: repo,
                child: const AccountDeletionGate(child: Text('Ứng dụng'))))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ứng dụng'), findsNothing);
    expect(find.text('Trạng thái yêu cầu'), findsOneWidget);
    repo.lookupFailure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Yêu cầu đang chờ xử lý'), findsOneWidget);
    expect(repo.cancellations, 0);
    repo.cancelWait = Completer<void>();
    await tester.tap(find.text('Đăng nhập lại'));
    await tester.pump();
    expect(find.text('Ứng dụng'), findsNothing);
    repo.cancelWait!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Ứng dụng'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small viewport, keyboard and large text scroll without overflow',
      (tester) async {
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPadding);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = FakeDeletion();
    await host(tester, repo, width: 320, height: 640);
    await openOtp(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'farewell and like animate joints independently of body and stop for reduced motion',
      () {
    for (final mood in [MascotMood.farewell, MascotMood.thumbsUp]) {
      final ctl = MascotController()..play(mood);
      final rig = MascotRig()..setMood(mood, ledge: 360, still: true);
      rig.tick(0, ctl: ctl, still: true);
      final hand = rig.value('hry'), body = rig.value('y');
      for (var i = 0; i < 60; i++) {
        rig.tick(1 / 60, ctl: ctl, still: false);
      }
      expect(rig.value('hry'), isNot(hand));
      expect(rig.value('y'), isNot(body));
      final time = rig.time;
      rig.tick(0, ctl: ctl, still: true);
      expect(rig.time, time);
      expect(rig.blink, 1);
      rig.dispose();
      ctl.dispose();
    }
  });
}
