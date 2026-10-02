import 'dart:async';

import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository giữ việc đọc phiên đã lưu ở trạng thái chờ, để thấy màn chờ của app.
class _PendingSessionRepository extends InMemoryAuthRepository {
  _PendingSessionRepository() : super(simulatedDelay: Duration.zero);

  final pending = Completer<AuthSession?>();

  @override
  Future<AuthSession?> getCurrentSession() => pending.future;
}

Finder _assetImage(String asset) => find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          switch (widget.image) {
            AssetImage(:final assetName) => assetName == asset,
            ResizeImage(imageProvider: AssetImage(:final assetName)) => assetName == asset,
            _ => false,
          },
    );

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  AuthController? controller,
  double textScale = 1.0,
}) async {
  final auth = controller ?? AuthController(InMemoryAuthRepository(simulatedDelay: Duration.zero));
  await tester.pumpWidget(AuthScope(
    controller: auth,
    child: MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: screen,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('màn chờ đọc phiên hiện mascot-hello và vòng xoay (AC20)', (tester) async {
    _setScreen(tester, const Size(412, 915));
    final repo = _PendingSessionRepository();

    await tester.pumpWidget(DrugTimeApp(
      authController: AuthController(repo),
      medicationRepository: InMemoryMedicationRepository(),
    ));
    await tester.pump();

    expect(_assetImage(AppAssets.mascotHello), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginMobileScreen), findsOneWidget);
  });

  testWidgets('màn Đăng nhập dùng mascot-hello thay cho logo vẽ bằng code (AC21)', (tester) async {
    _setScreen(tester, const Size(412, 915));
    await _pumpScreen(tester, const LoginMobileScreen());

    expect(_assetImage(AppAssets.mascotHello), findsOneWidget);
    expect(find.bySemanticsLabel('DrugTime'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(
      find.descendant(of: find.byType(LoginMobileScreen), matching: find.byType(CustomPaint)).evaluate().where(
            (e) => (e.widget as CustomPaint).painter.runtimeType.toString() == '_DrugTimeLogoPainter',
          ),
      isEmpty,
    );
  });

  testWidgets('màn Hoàn thiện hồ sơ có mascot-thinking phía trên form (AC22)', (tester) async {
    _setScreen(tester, const Size(412, 915));
    await _pumpScreen(tester, const CompleteProfileScreen());

    final mascot = _assetImage(AppAssets.mascotThinking);
    expect(mascot, findsOneWidget);
    expect(
      tester.getBottomLeft(mascot).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('profile-full-name'))).dy),
    );
  });

  group('màn nhỏ 360x640, chữ phóng to 1.5x: không tràn bố cục, cuộn tới nút chính', () {
    testWidgets('Đăng nhập (AC21)', (tester) async {
      _setScreen(tester, const Size(360, 640));
      await _pumpScreen(tester, const LoginMobileScreen(), textScale: 1.5);

      expect(tester.takeException(), isNull);
      final button = find.text('Gửi mã OTP');
      await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hoàn thiện hồ sơ (AC22)', (tester) async {
      _setScreen(tester, const Size(360, 640));
      await _pumpScreen(tester, const CompleteProfileScreen(), textScale: 1.5);

      expect(tester.takeException(), isNull);
      final button = find.text('Lưu và tiếp tục');
      await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });
  });
}
