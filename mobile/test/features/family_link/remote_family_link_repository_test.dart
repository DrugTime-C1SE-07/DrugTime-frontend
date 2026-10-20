import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/remote_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_request.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_request_failure.dart';
import 'package:flutter_test/flutter_test.dart';

const _uuid = '9b2e4c71-5d3a-4f8e-a1c6-7e0d2b9f4a58';

Map<String, Object?> linkRequestJson(String status) =>
    {'id': 15, 'status': status, 'requested_at': '2026-10-14T09:30:12+07:00'};

class _Request {
  _Request(this.method, this.uri, this.authorization, this.body);

  final String method;
  final Uri uri;
  final String? authorization;
  final String body;

  Object? get json => body.isEmpty ? null : jsonDecode(body);
}

/// Phản hồi giả: mã trạng thái, body (JSON hoặc chuỗi thô), header `Retry-After`.
typedef _Reply = (int, Object?, {String? retryAfter});

void main() {
  late HttpServer server;
  late List<_Request> requests;
  late List<_Reply> replies;
  late int unauthorizedCalls;
  late RemoteFamilyLinkRepository repo;

  setUp(() async {
    requests = [];
    replies = [];
    unauthorizedCalls = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(_Request(
        request.method,
        request.uri,
        request.headers.value(HttpHeaders.authorizationHeader),
        await utf8.decodeStream(request),
      ));
      final (status, body, :retryAfter) = replies.removeAt(0);
      request.response.statusCode = status;
      if (retryAfter != null) {
        request.response.headers.set(HttpHeaders.retryAfterHeader, retryAfter);
      }
      if (body is String) {
        request.response.write(body);
      } else if (body != null) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      }
      await request.response.close();
    });
    repo = RemoteFamilyLinkRepository(ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      authTokenProvider: () async => 'app-token',
      onUnauthorized: () async => unauthorizedCalls++,
    ));
  });

  tearDown(() => server.close(force: true));

  Future<LinkRequest> send() => repo.sendLinkRequest(code: 'K7M2Q9XAR4', clientUuid: _uuid);

  test('AC4, AC9: POST /family/link-requests, body đúng hai field, có Bearer; 201 → pending',
      () async {
    replies.add((201, linkRequestJson('pending'), retryAfter: null));

    final request = await send();

    expect(request.id, 15);
    expect(request.status, LinkRequestStatus.pending);
    expect(request.requestedAt, DateTime.parse('2026-10-14T09:30:12+07:00'));
    expect(requests.single.method, 'POST');
    expect(requests.single.uri.path, '/family/link-requests');
    expect(requests.single.authorization, 'Bearer app-token');
    expect(requests.single.json, {'client_uuid': _uuid, 'code': 'K7M2Q9XAR4'});
  });

  test('AC21: 200 gửi lại trả trạng thái hiện tại; giá trị lạ → unknown', () async {
    for (final status in ['pending', 'active', 'rejected', 'revoked', 'xyz']) {
      replies.add((200, linkRequestJson(status), retryAfter: null));
    }

    final statuses = [for (var i = 0; i < 5; i++) (await send()).status];

    expect(statuses, [
      LinkRequestStatus.pending,
      LinkRequestStatus.active,
      LinkRequestStatus.rejected,
      LinkRequestStatus.revoked,
      LinkRequestStatus.unknown,
    ]);
  });

  Future<void> expectFailure(
    _Reply reply,
    LinkRequestFailureKind kind, {
    Duration? retryAfter,
  }) async {
    replies.add(reply);
    await expectLater(
      send(),
      throwsA(isA<LinkRequestFailure>()
          .having((f) => f.kind, 'kind', kind)
          .having((f) => f.retryAfter, 'retryAfter', retryAfter)),
    );
  }

  test('AC6, AC9: mọi cặp (mã trạng thái, detail) của contract', () async {
    await expectFailure((404, {'detail': 'link_code_not_found'}, retryAfter: null),
        LinkRequestFailureKind.codeNotFound);
    await expectFailure((422, {'detail': 'self_link_not_allowed'}, retryAfter: null),
        LinkRequestFailureKind.selfLink);
    await expectFailure(
        (
          422,
          {
            'detail': [
              {'loc': ['body', 'code'], 'msg': 'x', 'type': 'string_pattern_mismatch'}
            ]
          },
          retryAfter: null
        ),
        LinkRequestFailureKind.invalidFormat);
    await expectFailure((409, {'detail': 'link_request_pending'}, retryAfter: null),
        LinkRequestFailureKind.alreadyPending);
    await expectFailure((409, {'detail': 'already_linked'}, retryAfter: null),
        LinkRequestFailureKind.alreadyLinked);
    await expectFailure((403, {'detail': 'khong_co_quyen'}, retryAfter: null),
        LinkRequestFailureKind.unknown);
  });

  test('AC20: 429 đọc Retry-After theo từng detail; thiếu header thì retryAfter null', () async {
    await expectFailure((429, {'detail': 'link_request_locked'}, retryAfter: '900'),
        LinkRequestFailureKind.locked,
        retryAfter: const Duration(seconds: 900));
    await expectFailure((429, {'detail': 'link_request_daily_limit'}, retryAfter: '3600'),
        LinkRequestFailureKind.dailyLimit,
        retryAfter: const Duration(hours: 1));
    await expectFailure((429, {'detail': 'link_request_cooldown'}, retryAfter: '86400'),
        LinkRequestFailureKind.cooldown,
        retryAfter: const Duration(days: 1));
    await expectFailure((429, {'detail': 'link_request_locked'}, retryAfter: null),
        LinkRequestFailureKind.locked);
  });

  test('AC8: 401 gọi onUnauthorized và trả unauthorized', () async {
    await expectFailure((401, {'detail': 'Missing bearer token'}, retryAfter: null),
        LinkRequestFailureKind.unauthorized);
    expect(unauthorizedCalls, 1);
  });

  test('AC7: 503, 500 → network', () async {
    await expectFailure((503, {'detail': 'unavailable'}, retryAfter: null),
        LinkRequestFailureKind.network);
    await expectFailure((500, 'Internal Server Error', retryAfter: null),
        LinkRequestFailureKind.network);
  });

  test('AC9: detail lạ, body không phải JSON, body 2xx sai contract → unknown', () async {
    await expectFailure((404, {'detail': 'something_else'}, retryAfter: null),
        LinkRequestFailureKind.unknown);
    await expectFailure((409, '<html>conflict</html>', retryAfter: null),
        LinkRequestFailureKind.unknown);
    await expectFailure((201, {'id': 'x'}, retryAfter: null), LinkRequestFailureKind.unknown);
    await expectFailure((201, 'not json', retryAfter: null), LinkRequestFailureKind.unknown);
  });

  test('AC7: không kết nối được máy chủ → network', () async {
    await server.close(force: true);

    await expectLater(
      send(),
      throwsA(isA<LinkRequestFailure>()
          .having((f) => f.kind, 'kind', LinkRequestFailureKind.network)),
    );
  });

  test('AC13: toString của lỗi không chứa mã hay body', () async {
    replies.add((404, {'detail': 'link_code_not_found'}, retryAfter: null));
    try {
      await send();
      fail('phải ném lỗi');
    } on LinkRequestFailure catch (failure) {
      expect(failure.toString(), isNot(contains('K7M2Q9XAR4')));
      expect(failure.toString(), isNot(contains('link_code_not_found')));
    }
  });
}
