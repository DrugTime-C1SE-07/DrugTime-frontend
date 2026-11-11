import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/drug_food_warning/data/models/food_interaction_mapper.dart';
import 'package:drugtime_mobile/features/drug_food_warning/domain/entities/drug_food_interaction.dart';

void main() {
  group('FoodInteractionMapper', () {
    test('fromJson parses complete payload successfully', () {
      final json = {
        'status': 'co_canh_bao',
        'warnings': [
          {
            'id': 'df-test-1',
            'medication_name': 'Atorvastatin 20mg',
            'active_ingredient': 'Atorvastatin',
            'food_name': 'Bưởi chùm',
            'food_category': 'Trái cây',
            'severity_level': 2,
            'mechanism_and_risk': 'Ức chế CYP3A4',
            'recommendation': 'Tránh ăn bưởi',
            'timing_advice': 'Tránh hoàn toàn',
            'source': 'Dược thư Quốc gia',
            'catalog_id': 101,
          }
        ],
        'insufficient_data_medications': ['Thuốc A'],
        'disclaimer': 'Custom disclaimer',
      };

      final result = FoodInteractionMapper.fromJson(json);

      expect(result.status, FoodInteractionStatus.found);
      expect(result.warnings.length, 1);
      final item = result.warnings.first;
      expect(item.id, 'df-test-1');
      expect(item.medicationName, 'Atorvastatin 20mg');
      expect(item.activeIngredient, 'Atorvastatin');
      expect(item.foodName, 'Bưởi chùm');
      expect(item.foodCategory, 'Trái cây');
      expect(item.severity, FoodInteractionSeverity.severe);
      expect(item.severityLevel, 2);
      expect(item.mechanismAndRisk, 'Ức chế CYP3A4');
      expect(item.recommendation, 'Tránh ăn bưởi');
      expect(item.timingAdvice, 'Tránh hoàn toàn');
      expect(item.source, 'Dược thư Quốc gia');
      expect(item.catalogId, 101);
      expect(result.insufficientDataMedications, ['Thuốc A']);
      expect(result.disclaimer, 'Custom disclaimer');
    });

    test('fromJson falls back to defaults on empty / null fields', () {
      final json = <String, dynamic>{};

      final result = FoodInteractionMapper.fromJson(json);

      expect(result.status, FoodInteractionStatus.noneFound);
      expect(result.warnings, isEmpty);
      expect(result.insufficientDataMedications, isEmpty);
      expect(result.disclaimer, nfr03Disclaimer);
    });

    test('toRequestBody maps fields correctly', () {
      final body = FoodInteractionMapper.toRequestBody(
        medicationName: 'Metformin',
        activeIngredient: 'Metformin hydrochloride',
        catalogId: 102,
        medicationIds: [101, 102],
      );

      expect(body['medication_name'], 'Metformin');
      expect(body['active_ingredient'], 'Metformin hydrochloride');
      expect(body['catalog_id'], 102);
      expect(body['medication_ids'], [101, 102]);
    });

    test('toRequestBody omits null or empty fields', () {
      final body = FoodInteractionMapper.toRequestBody(
        medicationName: '',
        activeIngredient: null,
      );

      expect(body.containsKey('medication_name'), isFalse);
      expect(body.containsKey('active_ingredient'), isFalse);
      expect(body.containsKey('catalog_id'), isFalse);
      expect(body.containsKey('medication_ids'), isFalse);
    });
  });
}
