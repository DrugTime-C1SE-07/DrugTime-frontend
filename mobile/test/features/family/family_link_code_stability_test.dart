import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:drugtime_mobile/features/family/data/repositories/remote_family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/screens/family_link_code_screen.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_link_code_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeFamilyLinkCodeRepository implements FamilyLinkCodeRepository {
  _FakeFamilyLinkCodeRepository({FamilyLinkCode? initialCode})
      : _currentCode = initialCode;

  FamilyLinkCode? _currentCode;
  int fetchCalls = 0;
  final List<String> methodsCalled = [];

  void setCode(FamilyLinkCode code) {
    _currentCode = code;
  }

  @override
  Future<FamilyLinkCode> fetch() async {
    fetchCalls++;
    methodsCalled.add('fetch');
    if (_currentCode == null) {
      throw const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.unavailable);
    }
    return _currentCode!;
  }
}

void main() {
  group('FamilyLinkCode stability & lifecycle tests', () {
    testWidgets(
        '1. UI/Controller cô lập trạng thái: hai controller nhận mã khác nhau từ repository thì hiển thị tách biệt, không dùng lẫn cache',
        (tester) async {
      // Ghi chú phạm vi: Việc cấp định danh duy nhất cho từng bệnh nhân thuộc trách nhiệm của Backend.
      // Test phía client chứng minh Controller và UI đảm bảo cô lập trạng thái hoàn toàn giữa các instance,
      // không dùng chung biến tĩnh hay rò rỉ cache giữa hai phiên/user khác nhau.
      final repoUserA = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'USERA12345',
          qrPayload: 'drugtime://link?code=USERA12345',
        ),
      );
      final repoUserB = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'USERB67890',
          qrPayload: 'drugtime://link?code=USERB67890',
        ),
      );

      final controllerA = FamilyLinkCodeController(repoUserA);
      final controllerB = FamilyLinkCodeController(repoUserB);
      addTearDown(() {
        controllerA.dispose();
        controllerB.dispose();
      });

      await controllerA.load();
      await controllerB.load();

      expect(controllerA.code?.code, 'USERA12345');
      expect(controllerB.code?.code, 'USERB67890');
      expect(controllerA.code?.code, isNot(equals(controllerB.code?.code)));

      // Render màn hình của User A
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controllerA,
          child: const FamilyLinkCodeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('USERA12345'), findsOneWidget);
      expect(find.text('USERB67890'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(controllerA.code?.qrPayload, 'drugtime://link?code=USERA12345');

      // Render màn hình của User B
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controllerB,
          child: const FamilyLinkCodeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('USERB67890'), findsOneWidget);
      expect(find.text('USERA12345'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(controllerB.code?.qrPayload, 'drugtime://link?code=USERB67890');
    });

    test(
        '2. Tính bất biến phía client: gọi load() nhiều lần chỉ thực hiện fetch() đọc dữ liệu, client không tự ý sinh hay yêu cầu đổi mã',
        () async {
      // Ghi chú phạm vi: Tính vĩnh viễn/cố định của mã do Backend quản trị dữ liệu đảm bảo.
      // Test phía client chứng minh interface FamilyLinkCodeRepository chỉ có phương thức fetch() đọc dữ liệu,
      // việc gọi load() nhiều lần là idempotent và client không hề có hành vi/lời gọi yêu cầu sinh mã mới.
      final repo = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'A1B2C3D4E5',
          qrPayload: 'drugtime://link?code=A1B2C3D4E5',
        ),
      );
      final controller = FamilyLinkCodeController(repo);
      addTearDown(controller.dispose);

      // Gọi load nhiều lần
      await controller.load();
      expect(controller.code?.code, 'A1B2C3D4E5');

      await controller.load();
      expect(controller.code?.code, 'A1B2C3D4E5');

      await controller.load();
      expect(controller.code?.code, 'A1B2C3D4E5');

      // Kiểm tra client chỉ gọi fetch() đúng 3 lần, không có hàm nào để client tự sinh/thay đổi mã
      expect(repo.fetchCalls, 3);
      expect(repo.methodsCalled, ['fetch', 'fetch', 'fetch']);
    });

    testWidgets(
        '3. Tái tạo trạng thái qua vòng đời widget: mở lại màn hình với controller mới vẫn nạp đúng mã từ repository',
        (tester) async {
      final repo = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'STABLE9999',
          qrPayload: 'drugtime://link?code=STABLE9999',
        ),
      );

      // Dựng màn hình lần 1
      final controller1 = FamilyLinkCodeController(repo);
      addTearDown(controller1.dispose);
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controller1,
          child: const FamilyLinkCodeScreen(key: ValueKey('screen-1')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('STABLE9999'), findsOneWidget);

      // Đóng màn hình (unmount hoàn toàn)
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Dựng lại màn hình với controller mới
      final controller2 = FamilyLinkCodeController(repo);
      addTearDown(controller2.dispose);
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controller2,
          child: const FamilyLinkCodeScreen(key: ValueKey('screen-2')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('STABLE9999'), findsOneWidget);

      expect(repo.fetchCalls, 2);
    });

    testWidgets(
        '4. Tích hợp vòng đời phiên: Đăng xuất qua AuthController.signOut() xóa mã, đăng nhập lại nạp lại mã ổn định',
        (tester) async {
      // Test tích hợp luồng thực tế của DrugTimeApp:
      // app.dart dòng 265-271: _auth.addListener(_onAuthChanged) gọi _familyLinkCode.clear() khi đăng xuất (signOut).
      // Sau đó thực hiện đăng nhập lại trọn vẹn để chứng minh tính ổn định xuyên suốt chu kỳ: Đăng nhập -> Đăng xuất -> Đăng nhập lại.
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final authRepo = InMemoryAuthRepository(
        initialSession: AuthSession(
          userId: 'patient-user-1',
          accessToken: 'valid-token',
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          profileComplete: true,
        ),
        simulatedDelay: Duration.zero,
      )..verifiedProfileComplete = true;

      final authController = AuthController(authRepo);
      addTearDown(authController.dispose);

      final familyRepo = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'PATIENT10X',
          qrPayload: 'drugtime://link?code=PATIENT10X',
        ),
      );

      await tester.pumpWidget(DrugTimeApp(
        authController: authController,
        familyLinkCodeRepository: familyRepo,
      ));
      await tester.pumpAndSettle();

      // 1. Chuyển sang tab Người thân -> Màn hình hiển thị mã liên kết của bệnh nhân
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Người thân'));
      await tester.pumpAndSettle();
      expect(find.text('PATIENT10X'), findsOneWidget);

      // 2. Người dùng thực hiện Đăng xuất qua AuthController.signOut()
      await authController.signOut();
      await tester.pumpAndSettle();

      // Hook _onAuthChanged của DrugTimeApp chuyển về màn Đăng nhập và gọi clear() trên family controller
      expect(find.byType(LoginMobileScreen), findsOneWidget);
      expect(find.text('PATIENT10X'), findsNothing);

      // 3. Người dùng đăng nhập lại từ màn hình đăng nhập
      await tester.enterText(
        find.descendant(
          of: find.byType(PhoneInputField),
          matching: find.byType(TextField),
        ),
        '0900000001',
      );
      await tester.ensureVisible(find.byKey(const Key('terms-checkbox')));
      await tester.tap(find.byKey(const Key('terms-checkbox')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Gửi mã OTP'));
      await tester.tap(find.text('Gửi mã OTP'));
      await tester.pumpAndSettle();

      // Nhập mã OTP
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(OtpVerificationScreen),
          matching: find.byType(TextField),
        ),
        '123456',
      );
      await tester.pumpAndSettle();

      // Đã đăng nhập lại thành công vào AppShell
      expect(find.byType(AppShell), findsOneWidget);

      // 4. Mở lại tab Người thân -> Mã liên kết PATIENT10X được nạp lại ổn định
      await tester.tap(find.text('Người thân'));
      await tester.pumpAndSettle();
      expect(find.text('PATIENT10X'), findsOneWidget);
    });

    // Bằng chứng GIÁN TIẾP: chỉ kiểm UI không hiện chuỗi hết hạn/đếm ngược khi đồng hồ giả
    // trôi. Không chứng minh mã không hết hạn phía server (QD-04), việc đó thuộc backend.
    testWidgets(
        '5. Không hết hạn trên UI: virtual clock trôi +24h, +30 ngày, +1 năm mã không đổi, không có thông báo hết hạn hay đếm ngược',
        (tester) async {
      // Ghi chú: Tính không hết hạn của mã do server quản trị và kiểm soát (không trả trường TTL/hết hạn).
      // Test client chứng minh trên giao diện không có countdown timer, không có text "Hết hạn",
      // không có nút ép buộc tạo mã mới khi thời gian trôi qua.
      final repo = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'NOEXPIRE10',
          qrPayload: 'drugtime://link?code=NOEXPIRE10',
        ),
      );
      final controller = FamilyLinkCodeController(repo);
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controller,
          child: const FamilyLinkCodeScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('NOEXPIRE10'), findsOneWidget);

      // Cho đồng hồ ảo trôi qua 24 giờ
      await tester.pump(const Duration(hours: 24));
      expect(find.text('NOEXPIRE10'), findsOneWidget);
      expect(find.textContaining('Hết hạn'), findsNothing);
      expect(find.textContaining('hết hạn'), findsNothing);
      expect(find.textContaining('đếm ngược'), findsNothing);
      expect(find.textContaining('Tạo mã mới'), findsNothing);

      // Cho đồng hồ ảo trôi qua 30 ngày
      await tester.pump(const Duration(days: 30));
      expect(find.text('NOEXPIRE10'), findsOneWidget);
      expect(find.textContaining('Hết hạn'), findsNothing);
      expect(find.textContaining('hết hạn'), findsNothing);

      // Cho đồng hồ ảo trôi qua 365 ngày (1 năm)
      await tester.pump(const Duration(days: 365));
      expect(find.text('NOEXPIRE10'), findsOneWidget);
      expect(find.textContaining('Hết hạn'), findsNothing);
      expect(find.textContaining('hết hạn'), findsNothing);
    });

    testWidgets(
        '6. Tái sử dụng: mã không bị tiêu hao sau khi hiển thị hay sao chép',
        (tester) async {
      final repo = _FakeFamilyLinkCodeRepository(
        initialCode: const FamilyLinkCode(
          code: 'MULTIUSR88',
          qrPayload: 'drugtime://link?code=MULTIUSR88',
        ),
      );

      final controller = FamilyLinkCodeController(repo);
      addTearDown(controller.dispose);

      // Mở màn hình lần 1
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controller,
          child: const FamilyLinkCodeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Kiểm tra widget SelectableText chứa mã để người dùng copy nhiều lần
      final selectableTextFinder = find.byKey(const Key('family-link-code'));
      expect(selectableTextFinder, findsOneWidget);
      final selectableText =
          tester.widget<SelectableText>(selectableTextFinder);
      expect(selectableText.data, 'MULTIUSR88');

      // Thoát màn hình (unmount)
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // Mở lại màn hình liên kết
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controller,
          child: const FamilyLinkCodeScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Mã vẫn nguyên vẹn, không bị tiêu hao hay biến mất sau khi hiển thị/sao chép
      expect(find.text('MULTIUSR88'), findsOneWidget);
    });

    test(
        '7. Kiểm tra ràng buộc độ dài mã định danh tại RemoteFamilyLinkCodeRepository: độ dài 9, 11, 36 (UUID) -> ném invalidResponse; 10 ký tự -> thành công',
        () async {
      HttpOverrides.global = null;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final replies = <Map<String, dynamic>>[];
      server.listen((request) async {
        final body = replies.removeAt(0);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
        await request.response.close();
      });

      final repository = RemoteFamilyLinkCodeRepository(ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        authTokenProvider: () async => 'session-token',
      ));

      // 1. Độ dài 9 ký tự (thiếu 1 ký tự) -> ném invalidResponse
      replies.add({
        'code': '123456789',
        'qr_payload': 'drugtime://link?code=123456789',
      });
      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having(
          (failure) => failure.kind,
          'kind',
          FamilyLinkCodeFailureKind.invalidResponse,
        )),
      );

      // 2. Độ dài 11 ký tự (thừa 1 ký tự) -> ném invalidResponse
      replies.add({
        'code': '12345678901',
        'qr_payload': 'drugtime://link?code=12345678901',
      });
      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having(
          (failure) => failure.kind,
          'kind',
          FamilyLinkCodeFailureKind.invalidResponse,
        )),
      );

      // 3. Độ dài 36 ký tự (chuỗi định dạng UUID) -> ném invalidResponse
      replies.add({
        'code': '123e4567-e89b-12d3-a456-426614174000',
        'qr_payload':
            'drugtime://link?code=123e4567-e89b-12d3-a456-426614174000',
      });
      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having(
          (failure) => failure.kind,
          'kind',
          FamilyLinkCodeFailureKind.invalidResponse,
        )),
      );

      // 4. Đúng 10 ký tự -> thành công
      replies.add({
        'code': 'A1B2C3D4E5',
        'qr_payload': 'drugtime://link?code=A1B2C3D4E5',
      });
      final result = await repository.fetch();
      expect(result.code, 'A1B2C3D4E5');
      expect(result.code.length, 10);
      expect(result.qrPayload, 'drugtime://link?code=A1B2C3D4E5');
    });
  });
}
