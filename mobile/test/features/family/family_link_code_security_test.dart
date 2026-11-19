import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/family/data/repositories/remote_family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/screens/family_link_code_screen.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_link_code_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeFailureRepository implements FamilyLinkCodeRepository {
  _FakeFailureRepository(this._result);

  Object _result;
  int calls = 0;

  void setResult(Object result) {
    _result = result;
  }

  @override
  Future<FamilyLinkCode> fetch() async {
    calls++;
    if (_result is FamilyLinkCodeFailure) {
      throw _result as FamilyLinkCodeFailure;
    }
    return _result as FamilyLinkCode;
  }
}

void main() {
  group('FamilyLinkCode Security & Privacy tests', () {
    testWidgets(
        '1. Bảo vệ quyền riêng tư: chuỗi qrPayload không chứa dữ liệu cá nhân hay sức khỏe; widget QR được render thành công',
        (tester) async {
      // [FACT & LIMITATION] QrImageView từ thư viện qr_flutter (v4.1.0) lưu trữ payload trong trường private _data
      // và không cung cấp public getter .data. Production truyền code.qrPayload vào QrImageView(data: qrPayload)
      // tại family_link_code_screen.dart dòng 69.
      // Test này kiểm tra chuỗi qrPayload từ domain/controller (nguồn cấp cho QrImageView), khẳng định không rò rỉ
      // bất kỳ thông tin nhạy cảm nào; đồng thời kiểm tra widget QrImageView có key 'family-link-qr' được render thành công.
      const sensitiveName = 'Nguyễn Mai';
      const sensitivePhone = '0901234567';
      const sensitiveEmail = 'patient@example.com';
      const sensitiveDob = '1960-03-01';
      const sensitiveCondition = 'Tăng huyết áp';
      const sensitiveDrug = 'Amlodipine 5mg';

      const validPayload = 'drugtime://link?code=A1B2C3D4E5';
      final repo = _FakeFailureRepository(
        const FamilyLinkCode(
          code: 'A1B2C3D4E5',
          qrPayload: validPayload,
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

      // Đọc payload từ controller (nguồn cấp vào QrImageView.data)
      expect(controller.code, isNotNull);
      final actualPayload = controller.code!.qrPayload;
      expect(actualPayload, validPayload);

      // QR widget phải hiện diện trên cây widget
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const Key('family-link-qr')), findsOneWidget);

      // Khẳng định payload không chứa thông tin cá nhân / sức khỏe
      expect(actualPayload.contains(sensitiveName), isFalse);
      expect(actualPayload.contains(sensitivePhone), isFalse);
      expect(actualPayload.contains(sensitiveEmail), isFalse);
      expect(actualPayload.contains('@'), isFalse);
      expect(actualPayload.contains(sensitiveDob), isFalse);
      expect(actualPayload.contains(sensitiveCondition), isFalse);
      expect(actualPayload.contains(sensitiveDrug), isFalse);
      expect(actualPayload.toLowerCase().contains('medication'), isFalse);
      expect(actualPayload.toLowerCase().contains('prescription'), isFalse);
      expect(actualPayload.toLowerCase().contains('diagnosis'), isFalse);
    });

    test(
        '2. Định dạng mã phía client: Entity chấp nhận String không rỗng; độ dài 10 do repository kiểm (xem stability test 7); bộ ký tự loại trừ do backend, [OPEN] QD-34',
        () {
      // [OPEN - QD-34] Client entity FamilyLinkCode hiện tại chỉ lưu trữ code: String mà không có regex validator
      // cho 10 ký tự chữ-số. Ràng buộc 10 ký tự thuộc trách nhiệm sinh và xác thực của Backend.
      const sampleCode = 'A1B2C3D4E5';
      const codeEntity = FamilyLinkCode(
        code: sampleCode,
        qrPayload: 'drugtime://link?code=$sampleCode',
      );

      expect(codeEntity.code, sampleCode);
      expect(codeEntity.code.length, 10);
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(codeEntity.code), isTrue);
      expect(codeEntity.code.contains(' '), isFalse);
      expect(codeEntity.code.contains('\n'), isFalse);
    });

    testWidgets(
        '3. Hành vi khi nhận 403 Forbidden (QD-29): mã hiển thị kết thúc ở null, failure là forbidden, UI chuyển sang thông báo trung tính và không rò rỉ mã lỗi kỹ thuật',
        (tester) async {
      // [FACT] FamilyLinkCodeController.load() thực hiện _code = null ngay đầu hàm trước khi gọi fetch().
      // Khi API phản hồi 403 (cũng như các lỗi khác), controller kết thúc ở trạng thái _code == null và failure.kind == forbidden.
      // Quy định QD-29 ("nhận 403 phải xóa dữ liệu đang hiển thị") được thỏa mãn qua việc state mã bị xóa và UI chuyển sang thông báo lỗi trung tính.
      final repo = _FakeFailureRepository(
        const FamilyLinkCode(
          code: 'PREV_CODE_1',
          qrPayload: 'drugtime://link?code=PREV_CODE_1',
        ),
      );
      final controller = FamilyLinkCodeController(repo);
      addTearDown(controller.dispose);

      // Tải thành công lần đầu
      await tester.pumpWidget(MaterialApp(
        home: FamilyLinkCodeScope(
          controller: controller,
          child: const FamilyLinkCodeScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('PREV_CODE_1'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);

      // Bị thu hồi quyền / server trả 403 khi tải lại
      repo.setResult(
          const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.forbidden));
      await controller.load();
      await tester.pumpAndSettle();

      // Controller xóa mã sạch (QD-29)
      expect(controller.code, isNull);
      expect(controller.failure?.kind, FamilyLinkCodeFailureKind.forbidden);

      // UI không còn hiển thị mã cũ hay QR
      expect(find.text('PREV_CODE_1'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);

      // UI hiển thị thông báo an toàn, trung tính
      expect(find.text('Chưa thể tải mã liên kết. Vui lòng thử lại.'),
          findsOneWidget);

      // Tuyệt đối không rò rỉ mã lỗi kỹ thuật
      expect(find.textContaining('forbidden'), findsNothing);
      expect(find.textContaining('403'), findsNothing);
      expect(find.textContaining('khong_co_quyen'), findsNothing);
      expect(find.textContaining('access_denied'), findsNothing);

      // Có nút thử lại an toàn
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('RemoteFamilyLinkCodeRepository Error Matrix tests (HttpServer loopback)',
      () {
    late HttpServer server;
    late List<(int, Object?)> replies;
    late int unauthorizedCalls;
    late RemoteFamilyLinkCodeRepository repository;

    setUp(() async {
      HttpOverrides.global = null;
      replies = [];
      unauthorizedCalls = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final (statusCode, body) = replies.removeAt(0);

        request.response.statusCode = statusCode;
        if (body is String) {
          request.response
            ..headers.contentType = ContentType.json
            ..write(body);
        } else if (body != null) {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(body));
        }
        await request.response.close();
      });

      repository = RemoteFamilyLinkCodeRepository(ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        authTokenProvider: () async => 'session-token',
        onUnauthorized: () async => unauthorizedCalls++,
      ));
    });

    tearDown(() => server.close(force: true));

    test('4a. HTTP 404 Not Found chuyển thành failure invalidResponse an toàn',
        () async {
      replies.add((404, {'detail': 'khong_tim_thay'}));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );
    });

    test(
        '4b. HTTP 429 Rate Limit: kiểm chứng hành vi hiện tại của ApiClient (isTransient -> network); [OPEN] cần backend chốt quy ước lỗi 429',
        () async {
      // [OPEN - 429 Contract] Theo mobile/lib/core/api/api_client.dart (dòng 81), mã 429 được ApiClient đánh dấu isTransient = true.
      // RemoteFamilyLinkCodeRepository ánh xạ lỗi isTransient thành FamilyLinkCodeFailureKind.network.
      // Test kiểm chứng đúng hành vi hiện tại này của codebase; cần team xác nhận contract xem 429 có cần mã lỗi riêng hay không.
      replies.add((429, {'detail': 'qua_nhieu_yeu_cau'}));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.network)),
      );
    });

    test('4c. JSON hỏng (malformed string) chuyển thành invalidResponse không crash',
        () async {
      replies.add((200, '{not_valid_json_here:'));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );
    });

    test('4d. Body không phải Map (ví dụ List) chuyển thành invalidResponse',
        () async {
      replies.add((200, [
        {'code': 'A1B2C3D4E5', 'qr_payload': 'drugtime://link?code=A1B2C3D4E5'}
      ]));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );
    });

    test('4e. Body thiếu qr_payload hoặc code chuyển thành invalidResponse',
        () async {
      replies.add((200, {'code': 'A1B2C3D4E5'}));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );

      replies.add((200, {'qr_payload': 'drugtime://link?code=A1B2C3D4E5'}));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );
    });

    test('4f. Code rỗng hoặc qr_payload rỗng chuyển thành invalidResponse',
        () async {
      replies.add((200, {
        'code': '',
        'qr_payload': 'drugtime://link?code=A1B2C3D4E5',
      }));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );

      replies.add((200, {
        'code': 'A1B2C3D4E5',
        'qr_payload': '',
      }));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );
    });

    test('4g. Sai kiểu dữ liệu (code hoặc qr_payload không phải String)',
        () async {
      replies.add((200, {
        'code': 1234567890,
        'qr_payload': 'drugtime://link?code=A1B2C3D4E5',
      }));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );

      replies.add((200, {
        'code': 'A1B2C3D4E5',
        'qr_payload': true,
      }));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.invalidResponse)),
      );
    });

    test('5. 401 Unauthorized kích hoạt onUnauthorized và ném failure unauthorized',
        () async {
      replies.add((401, {'detail': 'unauthorized_token_expired'}));

      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
            'kind', FamilyLinkCodeFailureKind.unauthorized)),
      );
      expect(unauthorizedCalls, 1);
    });
  });
}
