import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/family/data/repositories/remote_family_alert_repository.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_alert.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_alert_repository.dart';

Map<String, dynamic> alertJson({int id = 1, bool read = false}) => {
      'id': id,
      'type': 'canh_bao_bo_lo_lieu_nguoi_than',
      'title': 'DrugTime',
      'content': 'Cảnh báo',
      'is_read': read,
      'about_patient_user_id': '00000000-0000-0000-0000-000000000001',
      'about_patient_name': 'Bác An',
      'medication_name': 'Thuốc A',
      'scheduled_at': '2026-10-21T19:30:00Z',
      'created_at': '2026-10-22T00:00:00+07:00',
    };

void main() {
  test('maps offset/time, nullable legacy and correct bearer/path/PATCH body',
      () async {
    final requests = <http.Request>[];
    final repo = RemoteFamilyAlertRepository(ApiClient(
        baseUrl: Uri.parse('http://localhost'),
        authTokenProvider: () async => 'session-A',
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer session-A');
          if (request.url.path == '/notifications') {
            return http.Response.bytes(
                utf8.encode(jsonEncode({
                  'items': [alertJson()],
                  'total': 1,
                  'unread_count': 1
                })),
                200);
          }
          return http.Response.bytes(
              utf8.encode(
                  jsonEncode(alertJson(read: request.method == 'PATCH'))),
              200);
        })));
    final page = await repo.list();
    expect(page.items.single.scheduledTimeVietnam, '02:30 · 22/10/2026');
    expect((await repo.detail(1)).isRead, false);
    expect((await repo.markRead(1)).isRead, true);
    expect(jsonDecode(requests.last.body), {'is_read': true});
    expect(
        FamilyAlert.fromJson(
                {...alertJson(), 'medication_name': null, 'scheduled_at': null})
            .isLegacy,
        true);
  });
  for (final status in [401, 403, 404, 503]) {
    test('maps HTTP $status without returning health data', () async {
      final repo = RemoteFamilyAlertRepository(ApiClient(
          baseUrl: Uri.parse('http://localhost'),
          httpClient: MockClient((_) async => http.Response('{}', status))));
      await expectLater(repo.detail(1), throwsA(isA<FamilyAlertFailure>()));
    });
  }
  test('rejects missing field, offset, invalid patient and mismatched ID',
      () async {
    for (final json in [
      {...alertJson()}..remove('medication_name'),
      {...alertJson(), 'scheduled_at': '2026-10-22T12:00:00'},
      {...alertJson(), 'about_patient_user_id': 'patient-from-push'},
    ]) {
      expect(() => FamilyAlert.fromJson(json), throwsFormatException);
    }
    final repo = RemoteFamilyAlertRepository(ApiClient(
        baseUrl: Uri.parse('http://localhost'),
        httpClient: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode(alertJson(id: 2))), 200))));
    await expectLater(repo.detail(1), throwsA(isA<FamilyAlertFailure>()));
  });
}
