import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/patient_monitor/data/patient_monitor_repository.dart';

Map<String, dynamic> historyJson(String patient) => {
      'patient_id': patient,
      'from': '2026-11-13',
      'to': '2026-11-19',
      'as_of': '2026-11-19T09:00:00+07:00',
      'patient_last_synced_at': null,
      'group_by': 'date',
      'timezone': 'Asia/Ho_Chi_Minh',
      'summary': {
        'total': 0,
        'taken': 0,
        'late': 0,
        'missed': 0,
        'pending': 0,
        'unverified': 0,
        'counted': 0,
        'adherence_rate': null
      },
      'groups': [],
    };

void main() {
  test(
      'all cursor pages, PRN, missing stock and server checkpoint are preserved',
      () async {
    final paths = <Uri>[];
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        httpClient: MockClient((request) async {
          paths.add(request.url);
          Object payload;
          if (request.url.path == '/adherence') {
            payload = historyJson('mother');
          } else if (request.url.path.endsWith('/schedules')) {
            payload = {'items': [], 'next_cursor': null};
          } else {
            final second = request.url.queryParameters['cursor'] == 'page2';
            payload = {
              'items': [
                {
                  'id': second ? 1 : 2,
                  'medication': {
                    'id': 10,
                    'name': 'Thuốc khi cần',
                    'active_ingredient': null,
                    'strength_text': null,
                    'dosage_form': null
                  },
                  'dosing_mode': 'as_needed',
                  'quantity_per_dose': 1,
                  'doses_per_day': 3,
                  'intake_timing': null,
                  'stock_quantity': second ? 0 : null,
                  'has_interaction_data': false,
                  'status': 'active',
                  'ended_at': null,
                  'schedules': [],
                }
              ],
              'next_cursor': second ? null : 'page2'
            };
          }
          return http.Response(jsonEncode(payload), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final data = await PatientMonitorRepository(api)
        .today('mother', now: DateTime.utc(2026, 11, 19, 2));
    expect(data.medications.length, 2);
    expect(data.medications.first.frequency.isAsNeeded, isTrue);
    expect(data.medications.first.stockRemaining, isNull);
    expect(data.medications.last.stockRemaining, 0);
    expect(data.report.checkpoint, isNull);
    expect(paths.where((uri) => uri.path.endsWith('/medications')).length, 2);
    expect(
        paths
            .where((uri) => uri.path == '/adherence')
            .single
            .queryParameters['patient_id'],
        'mother');
  });

  test('cross-patient adherence response is rejected', () async {
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode(historyJson('father')), 200)));
    await expectLater(
        PatientMonitorRepository(api).history(
            'mother', DateTime.utc(2026, 11, 13), DateTime.utc(2026, 11, 19)),
        throwsFormatException);
  });

  test(
      'food results use canonical GET and retain per-medication insufficient state',
      () async {
    final api = ApiClient(
        baseUrl: Uri.parse('https://test.invalid'),
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/patients/mother/food-interactions');
          return http.Response(
              jsonEncode({
                'patient_id': 'mother',
                'as_of': '2026-11-19T09:00:00+07:00',
                'status': 'khong_du_du_lieu',
                'medications': [],
                'disclaimer': 'Thông tin tham khảo'
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final result =
        await PatientMonitorRepository(api).foodInteractions('mother');
    expect(result['status'], 'khong_du_du_lieu');
  });
}
