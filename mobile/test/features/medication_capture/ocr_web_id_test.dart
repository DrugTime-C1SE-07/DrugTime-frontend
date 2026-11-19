import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Map<String, dynamic> resultWithId(int id) => {
      'status': 'matched',
      'items': [
        {
          'id': id,
          'name': 'Thuốc',
          'active_ingredient': null,
          'strength_text': null,
          'dosage_form': null,
          'has_active_ingredients': false,
          'score': 0.8,
        }
      ],
      'preselected_id': id,
      'suggested_query': null,
      'reasons': <String>[],
    };

void main() {
  test('web accepts safe integer and rejects unsafe or nonpositive ID', () {
    expect(OcrMatchResult.fromJson(resultWithId(9007199254740991)).items.single.id,
        9007199254740991);
    for (final id in [0, 9007199254740992]) {
      expect(() => OcrMatchResult.fromJson(resultWithId(id)),
          throwsA(isA<OcrFailure>()));
    }
  }, skip: !kIsWeb);
}
