import 'package:drugtime_mobile/features/adherence/data/models/adherence_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:flutter_test/flutter_test.dart';

const samplePatientId = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> sampleHistoryJson({
  String patientId = samplePatientId,
  bool empty = false,
}) {
  Map<String, Object?> summary({bool noCount = false}) => {
        'total': noCount ? 0 : 4,
        'taken': noCount ? 0 : 1,
        'late': noCount ? 0 : 1,
        'missed': noCount ? 0 : 1,
        'pending': noCount ? 0 : 1,
        'counted': noCount ? 0 : 3,
        'adherence_rate': noCount ? null : 66.67,
      };
  Map<String, Object?> dose(String status, String? takenAt, String source) => {
        'medication_id': 12,
        'medication_name': 'Thuốc A',
        'schedule_id': 34,
        'scheduled_at': '2026-10-22T08:00:00+07:00',
        'taken_at': takenAt,
        'status': status,
        'status_source': source,
      };
  return {
    'patient_id': patientId,
    'from': '2026-10-01',
    'to': '2026-10-22',
    'timezone': 'Asia/Ho_Chi_Minh',
    'as_of': '2026-10-22T12:00:00+07:00',
    'summary': summary(noCount: empty),
    'group_by': 'date',
    'groups': empty
        ? <Object>[]
        : [
            {
              'date': '2026-10-22',
              'summary': summary(),
              'doses': [
                dose('da_uong', '2026-10-22T08:05:00+07:00', 'recorded'),
                dose('uong_tre', '2026-10-22T10:05:00+07:00', 'recorded'),
                dose('bo_lo', null, 'inferred'),
                dose('cho_xac_nhan', null, 'inferred'),
              ],
            }
          ],
  };
}

void main() {
  test('parses all statuses, offset times and server rate', () {
    final history = AdherenceApiMapper.history(sampleHistoryJson());
    expect(history.patientId, samplePatientId);
    expect(history.summary.rate, 66.67);
    expect(history.groups.single.doses.map((d) => d.status),
        AdherenceDoseStatus.values);
    expect(history.groups.single.doses.first.scheduledAt.toUtc().hour, 1);
    expect(vietnamWallTime(history.groups.single.doses.first.takenAt!).hour, 8);
    expect(history.groups.single.doses.last.takenAt, isNull);
  });

  test('empty history has null rate and no fabricated groups', () {
    final history = AdherenceApiMapper.history(sampleHistoryJson(empty: true));
    expect(history.groups, isEmpty);
    expect(history.summary.rate, isNull);
  });

  test('rejects missing fields, invalid dates and inconsistent dose', () {
    final missing = sampleHistoryJson()..remove('patient_id');
    expect(() => AdherenceApiMapper.history(missing), throwsFormatException);

    final badDate = sampleHistoryJson()..['to'] = '2026-02-30';
    expect(() => AdherenceApiMapper.history(badDate), throwsFormatException);

    final badStatus = sampleHistoryJson();
    final group = (badStatus['groups'] as List).single as Map<String, Object?>;
    final first = (group['doses'] as List).first as Map<String, Object?>;
    first['taken_at'] = null;
    expect(() => AdherenceApiMapper.history(badStatus), throwsFormatException);
  });
}
