import 'package:drugtime_mobile/features/profile/data/models/profile_api_mapper.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/condition.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/profile_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nullable profile and all gender aliases', () {
    final p = ProfileApiMapper.profile({
      'full_name': null,
      'date_of_birth': null,
      'gender': null,
      'conditions': []
    });
    expect(p.fullName, isNull);
    expect(p.conditions, isEmpty);
    for (final pair in {
      'male': 'nam',
      'female': 'nu',
      'other': 'khac',
      'nam': 'nam',
      'nu': 'nu',
      'khac': 'khac'
    }.entries) {
      expect(ProfileApiMapper.gender(pair.key), pair.value);
    }
  });
  test('PUT only supported fields, trim name and preserve calendar date', () {
    final body = ProfileApiMapper.updateBody(ProfileDraft(
        fullName: '  Mai  ', dateOfBirth: DateTime(1958, 3, 1), gender: 'nu'));
    expect(body,
        {'full_name': 'Mai', 'date_of_birth': '1958-03-01', 'gender': 'nu'});
  });
  test('Vietnam midnight boundary, blank name and future DOB', () {
    final now = DateTime.utc(2026, 10, 14, 17, 1);
    expect(ProfileDraft.todayInVietnam(now), DateTime(2026, 10, 15));
    expect(ProfileDraft.validateDate(DateTime(2026, 10, 15), now), isNull);
    expect(ProfileDraft.validateDate(DateTime(2026, 10, 16), now), isNotNull);
    expect(ProfileDraft.validateDate(null, now), isNotNull);
    expect(ProfileDraft.validateName('  '), isNotNull);
    expect(
        () => ProfileApiMapper.parseDate('2026-02-30'), throwsFormatException);
  });
  test('omitted metadata unchanged, null clears; preserve int64 IDs', () {
    const c = ProfileCondition(
        id: 9223372036854775806,
        conditionId: 9,
        name: 'Bệnh',
        subtype: 'A',
        stage: 'B');
    expect(ProfileApiMapper.id(c.id), 9223372036854775806);
    expect(() => ProfileApiMapper.id(9.0), throwsFormatException);
    expect(ProfileApiMapper.metadataChanges(c, subtype: 'A', stage: null),
        {'stage': null});
    expect(
        ProfileApiMapper.metadataChanges(c, subtype: 'A', stage: 'B'), isEmpty);
  });
  test('errors never expose raw payload and distinguish consent', () {
    final failure = ProfileApiMapper.failure(
        const ApiException('{"detail":"consent_revoked"}', statusCode: 403));
    expect(failure.kind, ProfileFailureKind.consent);
    expect(
        ProfileApiMapper.failure(
                const ApiException('Private data', statusCode: 500))
            .message,
        isNot(contains('Private data')));
    expect(
        ProfileApiMapper.failure(const ApiException('bad', statusCode: 403))
            .kind,
        ProfileFailureKind.forbidden);
  });
}
