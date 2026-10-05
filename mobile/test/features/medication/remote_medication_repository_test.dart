import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/remote_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'medication_api_mapper_test.dart' show base, userMedicationJson;

class _Request {
  _Request(this.method, this.uri, this.authorization, this.body);

  final String method;
  final Uri uri;
  final String? authorization;
  final String body;

  Object? get json => body.isEmpty ? null : jsonDecode(body);
}

void main() {
  late HttpServer server;
  late List<_Request> requests;

  /// Phản hồi kế tiếp: (status, body JSON hoặc null). Hết hàng đợi thì trả 200 thuốc mẫu.
  late List<(int, Object?)> replies;
  late int unauthorizedCalls;
  late RemoteMedicationRepository repo;

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
      final (status, body) = replies.isEmpty ? (200, userMedicationJson()) : replies.removeAt(0);
      request.response.statusCode = status;
      if (body != null) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      }
      await request.response.close();
    });
    repo = RemoteMedicationRepository(ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      authTokenProvider: () async => 'app-token',
      onUnauthorized: () async => unauthorizedCalls++,
    ));
  });

  tearDown(() => server.close(force: true));

  test('fetchAll đọc items của GET /medications', () async {
    replies.add((200, {'items': [userMedicationJson(), userMedicationJson(status: 'stopped')]}));

    final meds = await repo.fetchAll();

    expect(meds, hasLength(2));
    expect(meds.last.isActive, isFalse);
    expect(requests.single.method, 'GET');
    expect(requests.single.uri.path, '/medications');
    expect(requests.single.authorization, 'Bearer app-token');
  });

  test('add gửi POST /medications với client_uuid và Bearer (AC8)', () async {
    replies.add((201, userMedicationJson()));

    final created = await repo.add(base(), clientUuid: '6f1c2a9e-4b7d-4e0a-9c55-2d8f3b1a7e10');

    expect(created.id, '42');
    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.uri.path, '/medications');
    expect(req.authorization, 'Bearer app-token');
    expect((req.json as Map)['client_uuid'], '6f1c2a9e-4b7d-4e0a-9c55-2d8f3b1a7e10');
  });

  test('gửi lại sau lỗi mạng dùng cùng client_uuid; server trả 200 thuốc cũ (AC9)', () async {
    replies
      ..add((503, {'detail': 'unavailable'}))
      ..add((200, userMedicationJson()));

    await expectLater(
      repo.add(base(), clientUuid: 'same-uuid'),
      throwsA(isA<MedicationFailure>()
          .having((f) => f.kind, 'kind', MedicationFailureKind.network)),
    );
    final again = await repo.add(base(), clientUuid: 'same-uuid');

    expect(again.id, '42');
    expect(requests.map((r) => (r.json as Map)['client_uuid']), ['same-uuid', 'same-uuid']);
  });

  test('setStopped gửi PATCH {"stopped": true/false} (AC12, AC14e)', () async {
    replies
      ..add((200, userMedicationJson(status: 'stopped', times: [])))
      ..add((200, userMedicationJson()));

    final stopped = await repo.setStopped('42', true);
    final resumed = await repo.setStopped('42', false);

    expect(stopped.isActive, isFalse);
    expect(resumed.isActive, isTrue);
    expect(requests.map((r) => r.method), ['PATCH', 'PATCH']);
    expect(requests.map((r) => r.uri.path), ['/medications/42', '/medications/42']);
    expect(requests.map((r) => r.json), [
      {'stopped': true},
      {'stopped': false},
    ]);
  });

  test('update chỉ gửi field đổi; không đổi gì thì không gọi API (AC13)', () async {
    final before = base();

    await repo.update(before, before.copyWith(dosePerIntake: 2));
    final unchanged = await repo.update(before, before);

    expect(unchanged, same(before));
    expect(requests.single.method, 'PATCH');
    expect(requests.single.json, {'quantity_per_dose': 2.0});
  });

  test('delete: 204 thành công; 404 khi gửi lại cũng coi là đã xoá; 403 ném lỗi (AC14e)', () async {
    replies
      ..add((204, null))
      ..add((404, {'detail': 'user_medication_not_found'}))
      ..add((403, {'detail': 'khong_co_quyen'}));

    await repo.delete('42');
    await repo.delete('42');
    await expectLater(
      repo.delete('42'),
      throwsA(isA<MedicationFailure>()
          .having((f) => f.kind, 'kind', MedicationFailureKind.forbidden)),
    );
    expect(requests.map((r) => r.method), ['DELETE', 'DELETE', 'DELETE']);
  });

  test('searchCatalog: chuỗi rỗng không gọi API; có chữ thì gửi q', () async {
    replies.add((
      200,
      {
        'items': [
          {
            'id': 5003,
            'name': 'Thuốc ho Bảo Thanh',
            'active_ingredient': null,
            'strength_text': null,
            'dosage_form': 'Siro',
          },
        ],
      }
    ));

    expect(await repo.searchCatalog('   '), isEmpty);
    expect(requests, isEmpty);

    final found = await repo.searchCatalog(' thuoc ho ');
    expect(found.single.name, 'Thuốc ho Bảo Thanh');
    expect(requests.single.uri.path, '/catalog/medications');
    expect(requests.single.uri.queryParameters, {'q': 'thuoc ho'});
  });

  test('401 gọi onUnauthorized và ném unauthorized (AC11)', () async {
    replies.add((401, {'detail': 'Token expired'}));

    await expectLater(
      repo.fetchAll(),
      throwsA(isA<MedicationFailure>()
          .having((f) => f.kind, 'kind', MedicationFailureKind.unauthorized)),
    );
    expect(unauthorizedCalls, 1);
  });

  test('422 mã nghiệp vụ được dịch (AC10)', () async {
    replies.add((422, {'detail': 'catalog_medication_not_found'}));

    await expectLater(
      repo.add(base(), clientUuid: 'u'),
      throwsA(isA<MedicationFailure>()
          .having((f) => f.kind, 'kind', MedicationFailureKind.catalogNotFound)),
    );
  });

  test('Medication mẫu dùng trong test có catalogId số như server', () {
    expect(int.tryParse(base().catalogId), isNotNull);
    expect(base().frequency, DoseFrequency.twice);
  });
}
