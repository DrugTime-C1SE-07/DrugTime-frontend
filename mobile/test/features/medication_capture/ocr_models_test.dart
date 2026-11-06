import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/capture_models.dart';

Map<String, dynamic> matchedJson() => {
      'status': 'matched',
      'items': [
        {
          'id': 9223372036854775807,
          'name': 'Thuốc mẫu',
          'active_ingredient': null,
          'strength_text': null,
          'dosage_form': null,
          'has_active_ingredients': false,
          'score': 0.8
        }
      ],
      'preselected_id': 9223372036854775807,
      'suggested_query': null,
      'reasons': ['strength_unverified']
    };

void main() {
  test(
      'preserves int64, nulls and metadata; result has no selected drug or image',
      () {
    final result = OcrMatchResult.fromJson(matchedJson());
    expect(result.items.single.id, 9223372036854775807);
    expect(result.items.single.strengthText, isNull);
    expect(result.reasons, ['strength_unverified']);
    expect(CaptureResult.candidates(result).image, isNull);
    expect(() => result.items.clear(), throwsUnsupportedError);
  });
  test('all three statuses; no-match is a successful empty result', () {
    final low = matchedJson()..['status'] = 'low_confidence';
    low['preselected_id'] = null;
    low['suggested_query'] = 'thuoc';
    expect(OcrMatchResult.fromJson(low).status, OcrMatchStatus.lowConfidence);
    expect(
        OcrMatchResult.fromJson({
          'status': 'no_match',
          'items': [],
          'preselected_id': null,
          'suggested_query': null,
          'reasons': []
        }).items,
        isEmpty);
  });
  test('rejects malformed status, shape, score, preselection and reasons', () {
    for (final entry in <String, Object?>{
      'status': 'unknown',
      'preselected_id': 1,
      'items': [],
      'suggested_query': 'query',
      'reasons': ['unknown']
    }.entries) {
      expect(
          () =>
              OcrMatchResult.fromJson(matchedJson()..[entry.key] = entry.value),
          throwsA(isA<OcrFailure>()));
    }
    for (final bad in [double.nan, -0.1, 1.1, '0.8', null]) {
      final json = matchedJson();
      (json['items'] as List).first['score'] = bad;
      expect(() => OcrMatchResult.fromJson(json), throwsA(isA<OcrFailure>()));
    }
  });
  test('validates Unicode code points and limits without changing text', () {
    for (final length in [1999, 2000]) {
      validateOcrText('😀' * length, 5);
    }
    expect(() => validateOcrText('😀' * 2001, 5), throwsA(isA<OcrFailure>()));
    expect(() => validateOcrText(' \r\n', 5), throwsA(isA<OcrFailure>()));
    for (final limit in [1, 10]) {
      validateOcrText('A\r\nB', limit);
    }
    for (final limit in [0, 11]) {
      expect(() => validateOcrText('A', limit), throwsA(isA<OcrFailure>()));
    }
  });
}
