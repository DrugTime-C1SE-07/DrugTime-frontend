import 'dart:async';

import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_request.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_request_failure.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/widgets/link_request_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_link_test_helpers.dart';

final _field = find.byKey(const Key('link-code-field'));
final _submit = find.byKey(const Key('link-code-submit'));
final _error = find.byKey(const Key('link-request-error'));

final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

LinkRequest _request(LinkRequestStatus status) =>
    LinkRequest(id: 1, status: status, requestedAt: DateTime(2026, 10, 20));

String _fieldText(WidgetTester tester) => tester.widget<TextField>(_field).controller!.text;

bool _submitEnabled(WidgetTester tester) => tester.widget<FilledButton>(_submit).onPressed != null;

Future<InMemoryFamilyLinkRepository> _pump(
  WidgetTester tester, {
  List<Object>? responses,
  EnterLinkCodeArgs args = const EnterLinkCodeArgs(),
}) async {
  final repo = InMemoryFamilyLinkRepository(responses: responses);
  await pumpFamilyLink(tester, EnterLinkCodeScreen(args: args), repository: repo);
  return repo;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AC3: mã gõ thường có khoảng trắng/gạch nối được chuẩn hóa và chia nhóm',
      (tester) async {
    final repo = await _pump(tester);

    await _type(tester, 'k7m2 q9xa-r4');

    expect(_fieldText(tester), 'K7M2 Q9XA R4');
    expect(_submitEnabled(tester), isTrue);
    expect(repo.calls, isEmpty);
  });

  testWidgets('AC3 BVA: 11 ký tự bị cắt còn 10, 10 ký tự bật nút', (tester) async {
    await _pump(tester);

    await _type(tester, 'K7M2Q9XAR4K');
    expect(_fieldText(tester), 'K7M2 Q9XA R4');
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('AC3: dán chuỗi QR hoặc link mời thì ô được điền đúng mã', (tester) async {
    await _pump(tester);

    await _type(tester, 'drugtime://link?code=K7M2Q9XAR4');
    expect(_fieldText(tester), 'K7M2 Q9XA R4');

    await _type(tester, '');
    await _type(tester, 'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR5');
    expect(_fieldText(tester), 'K7M2 Q9XA R5');
  });

  testWidgets('AC3: 9 ký tự hoặc ký tự ngoài bảng mã → lỗi dưới ô, nút tắt, không gọi',
      (tester) async {
    final repo = await _pump(tester);

    await _type(tester, 'K7M2Q9XAR');
    expect(find.text('Mã cần đủ 10 ký tự (còn thiếu 1).'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    await _type(tester, 'K7M2Q9XA01');
    expect(find.text('Mã chỉ gồm chữ và số, không có 0, O, 1, I, L.'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    await tester.tap(_submit);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('AC4: gửi thành công → màn Đang chờ xác nhận, không có nút hủy', (tester) async {
    final repo = await _pump(tester);

    await _type(tester, 'k7m2q9xar4');
    await _tapSubmit(tester);

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.code, 'K7M2Q9XAR4');
    expect(repo.calls.single.clientUuid, matches(_uuidV4));
    expect(find.byType(LinkRequestResultScreen), findsOneWidget);
    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
    expect(find.textContaining('Người thân cần chấp thuận'), findsOneWidget);
    expect(find.textContaining('Hủy'), findsNothing);
    expect(find.textContaining('Huỷ'), findsNothing);
  });

  testWidgets('AC5: bấm Gửi 3 lần khi request đầu chưa xong → 1 lần gọi, có chỉ báo',
      (tester) async {
    final pending = Completer<LinkRequest>();
    final repo = await _pump(tester, responses: [pending]);
    await _type(tester, 'K7M2Q9XAR4');

    for (var i = 0; i < 3; i++) {
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pump();
    }

    expect(repo.calls, hasLength(1));
    expect(find.byKey(const Key('link-code-sending')), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    pending.complete(_request(LinkRequestStatus.pending));
    await tester.pumpAndSettle();
    expect(find.byType(LinkRequestResultScreen), findsOneWidget);
  });

  testWidgets('AC6: mỗi lỗi hiện đúng câu, ở lại màn, giữ mã', (tester) async {
    const cases = {
      LinkRequestFailureKind.codeNotFound: linkCodeNotFoundMessage,
      LinkRequestFailureKind.selfLink: 'Đây là mã của chính bạn.',
      LinkRequestFailureKind.invalidFormat: 'Mã không đúng định dạng.',
      LinkRequestFailureKind.alreadyLinked: 'Bạn đã theo dõi người này rồi.',
      LinkRequestFailureKind.unknown: 'Đã có lỗi xảy ra, thử lại.',
    };
    final repo = await _pump(tester, responses: [
      for (final kind in cases.keys) LinkRequestFailure(kind),
    ]);
    await _type(tester, 'K7M2Q9XAR4');

    for (final message in cases.values) {
      await _tapSubmit(tester);
      expect(find.descendant(of: _error, matching: find.text(message)), findsOneWidget);
      expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
      expect(find.byType(LinkRequestResultScreen), findsNothing);
      expect(_fieldText(tester), 'K7M2 Q9XA R4');
    }
    expect(repo.calls, hasLength(cases.length));
  });

  testWidgets('AC7: lỗi mạng → Thử lại gửi cùng client_uuid; sửa mã thì client_uuid mới',
      (tester) async {
    final repo = await _pump(tester, responses: [
      const LinkRequestFailure(LinkRequestFailureKind.network),
      const LinkRequestFailure(LinkRequestFailureKind.network),
      const LinkRequestFailure(LinkRequestFailureKind.network),
    ]);
    await _type(tester, 'K7M2Q9XAR4');

    await _tapSubmit(tester);
    expect(find.text('Không kết nối được, thử lại.'), findsOneWidget);
    expect(find.descendant(of: _submit, matching: find.text('Thử lại')), findsOneWidget);
    await _tapSubmit(tester);
    await _type(tester, 'K7M2Q9XAR5');
    await _tapSubmit(tester);

    expect(repo.calls[0].clientUuid, repo.calls[1].clientUuid);
    expect(repo.calls[2].clientUuid, isNot(repo.calls[0].clientUuid));
    // Không tự gửi lại trong nền.
    await tester.pump(const Duration(minutes: 1));
    expect(repo.calls, hasLength(3));
  });

  testWidgets('AC20: 429 + 900 giây → câu kèm 15:00, nút tắt, hết giờ mở lại và không tự gửi',
      (tester) async {
    final repo = await _pump(tester, responses: [
      const LinkRequestFailure(LinkRequestFailureKind.locked,
          retryAfter: Duration(seconds: 900)),
    ]);
    await _type(tester, 'K7M2Q9XAR4');

    await _tapSubmit(tester);
    expect(find.text('Bạn đã nhập sai mã nhiều lần. Thử lại sau 15:00.'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);
    await tester.tap(_submit, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Bạn đã nhập sai mã nhiều lần. Thử lại sau 14:59.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 899));
    expect(_submitEnabled(tester), isTrue);
    expect(repo.calls, hasLength(1));
  });

  testWidgets('AC20 (M2): đang bị khóa mà sửa mã thì câu báo và thời gian vẫn hiện', (tester) async {
    await _pump(tester, responses: [
      const LinkRequestFailure(LinkRequestFailureKind.locked, retryAfter: Duration(seconds: 900)),
    ]);
    await _type(tester, 'K7M2Q9XAR4');
    await _tapSubmit(tester);

    await _type(tester, 'K7M2Q9XAR5');

    expect(find.text('Bạn đã nhập sai mã nhiều lần. Thử lại sau 15:00.'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);
  });

  testWidgets('AC20: 429 không có Retry-After → câu không có thời gian', (tester) async {
    await _pump(tester, responses: [
      const LinkRequestFailure(LinkRequestFailureKind.cooldown),
    ]);
    await _type(tester, 'K7M2Q9XAR4');

    await _tapSubmit(tester);

    expect(find.text('Người này đã từ chối nhiều lần liên tiếp.'), findsOneWidget);
  });

  testWidgets('AC21: 409 pending → màn chờ', (tester) async {
    await _pump(tester, responses: [
      const LinkRequestFailure(LinkRequestFailureKind.alreadyPending),
    ]);
    await _type(tester, 'K7M2Q9XAR4');

    await _tapSubmit(tester);

    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
  });

  testWidgets('AC21: gửi lại nhận active → đã chấp thuận; rejected → ở lại; lạ → màn chờ',
      (tester) async {
    await _pump(tester, responses: [_request(LinkRequestStatus.active)]);
    await _type(tester, 'K7M2Q9XAR4');
    await _tapSubmit(tester);
    expect(find.text('Đã được chấp thuận'), findsOneWidget);

    await _pump(tester, responses: [_request(LinkRequestStatus.rejected)]);
    await _type(tester, 'K7M2Q9XAR4');
    await _tapSubmit(tester);
    expect(find.text('Yêu cầu này không còn hiệu lực. Bạn có thể gửi lại.'), findsOneWidget);
    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);

    await _pump(tester, responses: [_request(LinkRequestStatus.unknown)]);
    await _type(tester, 'K7M2Q9XAR4');
    await _tapSubmit(tester);
    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
  });

  testWidgets('AC16: mở với mã từ link → điền sẵn, chưa gửi; link sai → thông báo, ô trống',
      (tester) async {
    final repo = await _pump(tester, args: const EnterLinkCodeArgs(initialCode: 'K7M2Q9XAR4'));
    expect(_fieldText(tester), 'K7M2 Q9XA R4');
    expect(_submitEnabled(tester), isTrue);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await _pump(tester, args: const EnterLinkCodeArgs(invalidLink: true));
    expect(find.text(invalidInviteLinkMessage), findsOneWidget);
    expect(_fieldText(tester), isEmpty);
  });

  testWidgets('AC13: gửi không đụng tới secure storage hay SQLite', (tester) async {
    final calls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'com.tekartik.sqflite',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        calls.add('$channel.${call.method}');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(MethodChannel(channel), null));
    }
    await _pump(tester, responses: [const LinkRequestFailure(LinkRequestFailureKind.network)]);
    await _type(tester, 'K7M2Q9XAR4');

    await _tapSubmit(tester);
    await _tapSubmit(tester);

    expect(calls, isEmpty);
  });
}
