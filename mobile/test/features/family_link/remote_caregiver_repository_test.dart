import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/remote_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/caregiver_failure.dart';
import 'package:flutter_test/flutter_test.dart';

const _family = 'b7dd501a-4ebe-4564-a171-d317710effaa';

Map<String, Object?> caregiverJson({
  int linkId = 42,
  String? name = 'Nguyễn Văn An',
  bool sharing = true,
  String? approvedAt = '2026-10-15T10:05:00+07:00',
}) =>
    {
      'link_id': linkId,
      'family_user_id': _family,
      'family_full_name': name,
      'status': 'active',
      'sharing_enabled': sharing,
      'approved_at': approvedAt,
    };

class _Request {
  _Request(this.method, this.uri, this.contentType, this.body);

  final String method;
  final Uri uri;
  final String? contentType;
  final String body;

  Object? get json => body.isEmpty ? null : jsonDecode(body);
}

void main() {
  late HttpServer server;
  late List<_Request> requests;
  late List<(int, Object?)> replies;
  late RemoteCaregiverRepository repo;

  setUp(() async {
    requests = [];
    replies = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(_Request(
        request.method,
        request.uri,
        request.headers.value(HttpHeaders.contentTypeHeader),
        await utf8.decodeStream(request),
      ));
      final (status, body) = replies.removeAt(0);
      request.response.statusCode = status;
      if (body is String) {
        request.response.write(body);
      } else if (body != null) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      }
      await request.response.close();
    });
    repo = RemoteCaregiverRepository(ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      authTokenProvider: () async => 'app-token',
    ));
  });

  tearDown(() => server.close(force: true));

  test('listPendingRequests: GET /family/links?status=pending, tên null giữ null', () async {
    replies.add((200, {
      'items': [
        {
          'link_id': 42,
          'family_user_id': _family,
          'family_full_name': null,
          'status': 'pending',
          'requested_at': '2026-10-15T09:00:00+07:00',
        }
      ]
    }));

    final result = await repo.listPendingRequests();

    final request = requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/family/links');
    expect(request.uri.queryParameters, {'status': 'pending'});
    expect(request.body, isEmpty);
    expect(result.single.linkId, 42);
    expect(result.single.familyName, isNull);
    expect(result.single.requestedAt, DateTime.utc(2026, 10, 15, 2));
  });

  test('approve: POST đủ ba field, consent_confirmed luôn true', () async {
    replies.add((200, {'ok': true}));

    await repo.approve(linkId: 42, familyUserId: _family, documentVersion: '2026-10-v1');

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/family/links/42/approve');
    expect(request.uri.query, isEmpty);
    expect(request.json, {
      'family_user_id': _family,
      'consent_confirmed': true,
      'document_version': '2026-10-v1',
    });
  });

  for (final action in ['reject', 'revoke']) {
    test('$action: POST không body, không Content-Type', () async {
      replies.add((200, {'ok': true}));

      await (action == 'reject' ? repo.reject(42) : repo.revoke(42));

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/family/links/42/$action');
      expect(request.body, isEmpty);
      expect(request.contentType, isNull);
    });
  }

  test('listCaregivers: GET /family/caregivers không query, approved_at null giữ null', () async {
    replies.add((200, {
      'items': [
        caregiverJson(),
        caregiverJson(linkId: 31, name: null, sharing: false, approvedAt: null),
      ]
    }));

    final result = await repo.listCaregivers();

    expect(requests.single.method, 'GET');
    expect(requests.single.uri.path, '/family/caregivers');
    expect(requests.single.uri.query, isEmpty);
    expect(result.map((c) => c.linkId), [42, 31]);
    expect(result.first.approvedAt, DateTime.utc(2026, 10, 15, 3, 5));
    expect(result.last.familyName, isNull);
    expect(result.last.sharingEnabled, isFalse);
    expect(result.last.approvedAt, isNull);
  });

  for (final enabled in [true, false]) {
    test('setSharing($enabled): PATCH {sharing_enabled}, trả trạng thái server', () async {
      replies.add((200, caregiverJson(sharing: enabled)));

      final result = await repo.setSharing(42, enabled: enabled);

      expect(requests.single.method, 'PATCH');
      expect(requests.single.uri.path, '/family/links/42/sharing');
      expect(requests.single.json, {'sharing_enabled': enabled});
      expect(result.sharingEnabled, enabled);
    });
  }

  final failures = <(int, Object?), CaregiverFailureKind>{
    (403, {'detail': 'khong_co_quyen'}): CaregiverFailureKind.forbidden,
    (403, {'detail': 'consent_revoked'}): CaregiverFailureKind.consentRequired,
    (404, {'detail': 'family_link_not_found'}): CaregiverFailureKind.notFound,
    (409, {'detail': 'invalid_link_transition'}): CaregiverFailureKind.conflict,
    (409, {'detail': 'family_link_not_active'}): CaregiverFailureKind.conflict,
    (409, {'detail': 'link_approval_conflict'}): CaregiverFailureKind.conflict,
    (409, {'detail': 'consent_confirmation_missing'}): CaregiverFailureKind.confirmationMissing,
    (422, {'detail': 'consent_document_outdated'}): CaregiverFailureKind.documentOutdated,
    (422, {
      'detail': [
        {'loc': ['body'], 'msg': 'x', 'type': 'missing'}
      ]
    }): CaregiverFailureKind.invalid,
    (401, {'detail': 'Invalid bearer token'}): CaregiverFailureKind.unauthorized,
    (503, {'detail': 'service_unavailable'}): CaregiverFailureKind.network,
    (500, 'boom'): CaregiverFailureKind.network,
    (418, 'teapot'): CaregiverFailureKind.unknown,
  };
  for (final entry in failures.entries) {
    test('${entry.key.$1} ${jsonEncode(entry.key.$2)} → ${entry.value.name}', () async {
      replies.add(entry.key);

      await expectLater(
        repo.setSharing(42, enabled: true),
        throwsA(isA<CaregiverFailure>().having((f) => f.kind, 'kind', entry.value)),
      );
    });
  }

  test('body 2xx sai contract → unknown', () async {
    replies.add((200, {'items': 'not-a-list'}));

    await expectLater(
      repo.listCaregivers(),
      throwsA(isA<CaregiverFailure>()
          .having((f) => f.kind, 'kind', CaregiverFailureKind.unknown)),
    );
  });

  test('mất kết nối → network', () async {
    await server.close(force: true);

    await expectLater(
      repo.listPendingRequests(),
      throwsA(isA<CaregiverFailure>()
          .having((f) => f.kind, 'kind', CaregiverFailureKind.network)),
    );
  });
}
