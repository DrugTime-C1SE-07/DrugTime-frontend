import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/core/sync/api_schedule_remote_data_source.dart';

void main() {
  final syncedAt = DateTime.utc(2026, 11, 12, 3);

  ApiScheduleRemoteDataSource source(MockClient client) =>
      ApiScheduleRemoteDataSource(
        ApiClient(
          baseUrl: Uri.parse('https://api.test'),
          httpClient: client,
          authTokenProvider: () async => 'token',
        ),
        clock: () => syncedAt,
      );

  test('maps every field of a schedule item', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
          jsonEncode({
            'items': [_item(id: 7, quantity: 1.5, endedAt: null)],
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json'});
    });

    final result = await source(client).fetchSchedules(patientId: 'p-1');

    expect(requests.single.path, '/patients/p-1/schedules');
    expect(result, hasLength(1));
    final s = result.single;
    expect(s.id, 7);
    expect(s.patientUserId, 'p-1');
    expect(s.userMedicationId, 70);
    expect(s.medicationId, 700);
    expect(s.medicationName, 'Paracetamol');
    expect(s.strengthText, '500mg');
    expect(s.dosageForm, 'Viên nén');
    expect(s.quantityPerDose, '1.5');
    expect(s.dosesPerDay, 2);
    expect(s.intakeTime, '08:00:00');
    expect(s.daysOfWeek, [1, 3, 5]);
    expect(s.reminderEnabled, isTrue);
    expect(s.effectiveFrom, DateTime.utc(2026, 11, 1));
    expect(s.endedAt, isNull);
    expect(s.serverSyncedAt, syncedAt);
  });

  test('follows next_cursor until the last page', () async {
    final cursors = <String?>[];
    final client = MockClient((request) async {
      final cursor = request.url.queryParameters['cursor'];
      cursors.add(cursor);
      final body = cursor == null
          ? {'items': [_item(id: 1, quantity: 1)], 'next_cursor': 'c2'}
          : {
              'items': [
                _item(id: 2, quantity: 2, endedAt: '2026-12-01T00:00:00Z')
              ],
              'next_cursor': null,
            };
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });

    final result = await source(client).fetchSchedules(patientId: 'p-1');

    expect(cursors, [null, 'c2']);
    expect(result.map((s) => s.id), [1, 2]);
    expect(result.first.quantityPerDose, '1');
    expect(result.last.endedAt, DateTime.utc(2026, 12, 1));
  });

  test('throws on a malformed item instead of dropping it', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'items': [
            {'id': 'x'}
          ],
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json'}));

    await expectLater(
      source(client).fetchSchedules(patientId: 'p-1'),
      throwsA(isA<ApiException>()),
    );
  });

  for (final (field, value) in [
    ('days_of_week', ['1']),
    ('strength_text', 5),
    ('dosage_form', true),
  ]) {
    test('throws ApiException when $field has the wrong type', () async {
      final item = _item(id: 1, quantity: 1);
      if (field == 'days_of_week') {
        item['days_of_week'] = value;
      } else {
        item['medication'] = <String, Object?>{
          ...(item['medication'] as Map),
          field: value,
        };
      }
      final client = MockClient((_) async => http.Response(
          jsonEncode({'items': [item], 'next_cursor': null}), 200,
          headers: {'content-type': 'application/json'}));

      await expectLater(
        source(client).fetchSchedules(patientId: 'p-1'),
        throwsA(isA<ApiException>()),
      );
    });
  }

  test('propagates API errors', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'detail': 'forbidden'}), 403,
        headers: {'content-type': 'application/json'}));

    await expectLater(
      source(client).fetchSchedules(patientId: 'p-1'),
      throwsA(isA<ApiException>()),
    );
  });
}

Map<String, Object?> _item({
  required int id,
  required num quantity,
  String? endedAt,
}) =>
    {
      'id': id,
      'user_medication_id': id * 10,
      'medication': {
        'id': id * 100,
        'name': 'Paracetamol',
        'active_ingredient': 'Paracetamol',
        'strength_text': '500mg',
        'dosage_form': 'Viên nén',
      },
      'quantity_per_dose': quantity,
      'doses_per_day': 2,
      'intake_timing': 'after_meal',
      'intake_time': '08:00:00',
      'days_of_week': [1, 3, 5],
      'reminder_enabled': true,
      'effective_from': '2026-11-01T00:00:00Z',
      'ended_at': endedAt,
    };
