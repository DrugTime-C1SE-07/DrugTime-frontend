import 'dart:async';

import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_request.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_request_failure.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/link_request_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _host = 'drug-time-frontend.vercel.app';

LinkRequest _request(LinkRequestStatus status) =>
    LinkRequest(id: 1, status: status, requestedAt: DateTime(2026, 10, 20));

LinkRequestFailure _failure(LinkRequestFailureKind kind, {Duration? retryAfter}) =>
    LinkRequestFailure(kind, retryAfter: retryAfter);

void main() {
  late InMemoryFamilyLinkRepository repo;
  late LinkRequestController controller;
  late int uuidCount;

  setUp(() {
    repo = InMemoryFamilyLinkRepository();
    uuidCount = 0;
    controller = LinkRequestController(
      repo,
      inviteLinkHost: _host,
      uuidFactory: () => 'uuid-${++uuidCount}',
    );
  });

  tearDown(() => controller.dispose());

  test('AC3: mã chưa hợp lệ thì không gửi', () async {
    controller.updateInput('K7M2Q9XAR');
    expect(controller.canSubmit, isFalse);

    await controller.submit();

    expect(repo.calls, isEmpty);
  });

  test('AC3, AC4: mã gõ có khoảng trắng/gạch nối được chuẩn hóa trước khi gửi', () async {
    controller.updateInput('k7m2 q9xa-r4');

    await controller.submit();

    expect(repo.calls.single.code, 'K7M2Q9XAR4');
    expect(repo.calls.single.clientUuid, 'uuid-1');
    expect(controller.outcome, LinkSubmitOutcome.waiting);
  });

  test('AC5: gọi submit nhiều lần khi request đầu chưa xong chỉ gửi một lần', () async {
    final pending = Completer<LinkRequest>();
    repo.responses.add(pending);
    controller.updateInput('K7M2Q9XAR4');

    final first = controller.submit();
    await controller.submit();
    await controller.submit();
    expect(controller.isSending, isTrue);
    expect(controller.canSubmit, isFalse);

    pending.complete(_request(LinkRequestStatus.pending));
    await first;
    expect(repo.calls, hasLength(1));
  });

  test('AC7: lỗi mạng rồi gửi lại dùng cùng client_uuid; sửa mã thì client_uuid mới', () async {
    repo.responses.addAll([
      _failure(LinkRequestFailureKind.network),
      _failure(LinkRequestFailureKind.unknown),
      _failure(LinkRequestFailureKind.network),
    ]);
    controller.updateInput('K7M2Q9XAR4');

    await controller.submit();
    expect(controller.error, LinkSubmitError.network);
    await controller.submit();
    expect(controller.error, LinkSubmitError.unknown);
    controller.updateInput('K7M2Q9XAR5');
    await controller.submit();

    expect(repo.calls.map((c) => c.clientUuid), ['uuid-1', 'uuid-1', 'uuid-2']);
  });

  test('AC7: sau phản hồi 4xx dứt khoát, lần gửi sau dùng client_uuid mới', () async {
    repo.responses.add(_failure(LinkRequestFailureKind.codeNotFound));
    controller.updateInput('K7M2Q9XAR4');

    await controller.submit();
    expect(controller.error, LinkSubmitError.codeNotFound);
    await controller.submit();

    expect(repo.calls.map((c) => c.clientUuid), ['uuid-1', 'uuid-2']);
  });

  test('AC6: ánh xạ lỗi của repository sang lỗi hiển thị', () async {
    const cases = {
      LinkRequestFailureKind.codeNotFound: LinkSubmitError.codeNotFound,
      LinkRequestFailureKind.selfLink: LinkSubmitError.selfLink,
      LinkRequestFailureKind.invalidFormat: LinkSubmitError.invalidFormat,
      LinkRequestFailureKind.alreadyLinked: LinkSubmitError.alreadyLinked,
      LinkRequestFailureKind.unknown: LinkSubmitError.unknown,
    };
    controller.updateInput('K7M2Q9XAR4');
    for (final MapEntry(:key, :value) in cases.entries) {
      repo.responses.add(_failure(key));
      await controller.submit();
      expect(controller.error, value, reason: key.name);
      expect(controller.outcome, isNull);
    }
  });

  test('AC8: 401 không hiện lỗi về mã', () async {
    repo.responses.add(_failure(LinkRequestFailureKind.unauthorized));
    controller.updateInput('K7M2Q9XAR4');

    await controller.submit();

    expect(controller.error, isNull);
    expect(controller.outcome, isNull);
  });

  test('AC21: 409 pending và các status khi gửi lại', () async {
    controller.updateInput('K7M2Q9XAR4');

    repo.responses.add(_failure(LinkRequestFailureKind.alreadyPending));
    await controller.submit();
    expect(controller.outcome, LinkSubmitOutcome.waiting);

    for (final (status, outcome, error) in [
      (LinkRequestStatus.active, LinkSubmitOutcome.accepted, null),
      (LinkRequestStatus.unknown, LinkSubmitOutcome.waiting, null),
      (LinkRequestStatus.rejected, null, LinkSubmitError.requestClosed),
      (LinkRequestStatus.revoked, null, LinkSubmitError.requestClosed),
    ]) {
      final fresh = LinkRequestController(repo, inviteLinkHost: _host)
        ..updateInput('K7M2Q9XAR4');
      repo.responses.add(_request(status));
      await fresh.submit();
      expect(fresh.outcome, outcome, reason: status.name);
      expect(fresh.error, error, reason: status.name);
      fresh.dispose();
    }
  });

  testWidgets('AC20: 429 khóa gửi theo Retry-After, hết hạn thì mở lại và không tự gửi',
      (tester) async {
    repo.responses.add(_failure(LinkRequestFailureKind.locked,
        retryAfter: const Duration(seconds: 3)));
    controller.updateInput('K7M2Q9XAR4');

    await controller.submit();
    expect(controller.error, LinkSubmitError.locked);
    expect(controller.remaining, const Duration(seconds: 3));
    expect(controller.canSubmit, isFalse);

    await controller.submit();
    expect(repo.calls, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    expect(controller.remaining, const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(controller.remaining, isNull);
    expect(controller.canSubmit, isTrue);
    expect(repo.calls, hasLength(1));
  });

  testWidgets('AC20 (M2): sửa mã khi đang bị khóa vẫn giữ câu báo và đếm ngược', (tester) async {
    repo.responses.add(_failure(LinkRequestFailureKind.dailyLimit,
        retryAfter: const Duration(seconds: 60)));
    controller.updateInput('K7M2Q9XAR4');
    await controller.submit();

    controller.updateInput('K7M2Q9XAR5');

    expect(controller.error, LinkSubmitError.dailyLimit);
    expect(controller.remaining, const Duration(seconds: 60));
    expect(controller.canSubmit, isFalse);
    await tester.pump(const Duration(seconds: 60));
    expect(controller.remaining, isNull);
    expect(controller.canSubmit, isTrue);
    expect(repo.calls, hasLength(1));
  });

  testWidgets('AC20 (M2): cooldown chỉ áp cho patient cũ, sửa mã thì mở lại', (tester) async {
    repo.responses.add(_failure(LinkRequestFailureKind.cooldown,
        retryAfter: const Duration(hours: 24)));
    controller.updateInput('K7M2Q9XAR4');
    await controller.submit();
    expect(controller.canSubmit, isFalse);

    controller.updateInput('K7M2Q9XAR5');

    expect(controller.error, isNull);
    expect(controller.remaining, isNull);
    expect(controller.canSubmit, isTrue);
  });

  test('AC20: 429 không có Retry-After vẫn báo lỗi, không khóa nút', () async {
    repo.responses.add(_failure(LinkRequestFailureKind.dailyLimit));
    controller.updateInput('K7M2Q9XAR4');

    await controller.submit();

    expect(controller.error, LinkSubmitError.dailyLimit);
    expect(controller.remaining, isNull);
    expect(repo.calls, hasLength(1));
  });
}
