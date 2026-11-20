import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatStrength (AC7, QD-38)', () {
    test('chèn khoảng trắng giữa số và đơn vị', () {
      expect(formatStrength('500mg'), '500 mg');
      expect(formatStrength('5mg/80mg'), '5 mg/80 mg');
      expect(formatStrength('500µg'), '500 µg');
      expect(formatStrength('2%'), '2 %');
    });

    test('không đổi giá trị không có đơn vị và chuỗi đã có khoảng trắng', () {
      expect(formatStrength('0,04'), '0,04');
      expect(formatStrength('5 mg'), '5 mg');
      expect(formatStrength('  '), '');
    });
  });

  test('sourceLabel trả nhãn theo mã và null khi không rõ', () {
    expect(sourceLabel('duoc_thu_qg'), 'Dược thư Quốc gia Việt Nam');
    expect(sourceLabel('dav_drugbank'), isNotNull);
    expect(sourceLabel('qd_5948'), isNotNull);
    expect(sourceLabel(null), isNull);
    expect(sourceLabel('khac'), isNull);
  });

  test('strengthAndForm bỏ phần trống', () {
    expect(strengthAndForm('500mg', 'Viên nén'), '500 mg · Viên nén');
    expect(strengthAndForm('', 'Siro'), 'Siro');
    expect(strengthAndForm('500mg', null), '500 mg');
  });

  group('PillShape / PillColor (AC23)', () {
    test('fromApi khớp contract, giá trị lạ thành null', () {
      expect(PillShape.fromApi('round_tablet'), PillShape.roundTablet);
      expect(PillShape.fromApi('hexagon'), isNull);
      expect(PillShape.fromApi(null), isNull);
      expect(PillColor.fromApi('yellow'), PillColor.yellow);
      expect(PillColor.fromApi('teal'), isNull);
    });

    test('đủ 11 hình và 10 màu như contract', () {
      expect(PillShape.values.map((s) => s.apiValue), [
        'capsule', 'round_tablet', 'oblong_tablet', 'softgel', 'effervescent',
        'powder_sachet', 'syrup', 'drops', 'spray', 'injection_pen', 'topical',
      ]);
      expect(PillColor.values.map((c) => c.apiValue), [
        'white', 'yellow', 'orange', 'pink', 'red', 'brown', 'blue', 'green',
        'purple', 'gray',
      ]);
    });

    test('suggestFor suy hình từ dạng bào chế', () {
      expect(PillShape.suggestFor('Viên nang cứng'), PillShape.capsule);
      expect(PillShape.suggestFor('Viên nang mềm'), PillShape.softgel);
      expect(PillShape.suggestFor('Viên sủi'), PillShape.effervescent);
      expect(PillShape.suggestFor('Thuốc bột pha hỗn dịch uống'),
          PillShape.powderSachet);
      expect(PillShape.suggestFor('Dung dịch uống'), PillShape.syrup);
      expect(PillShape.suggestFor('Kem bôi da'), PillShape.topical);
      expect(PillShape.suggestFor('Viên nén'), PillShape.roundTablet);
      expect(PillShape.suggestFor(null), PillShape.roundTablet);
    });
  });

  test('Medication.withAppearance đặt và xóa được hình/màu', () {
    const base = Medication(
      id: '1',
      catalogId: '7',
      name: 'Paracetamol',
      activeIngredient: 'Paracetamol',
      strength: '500mg',
      unit: 'viên',
      dosePerIntake: 1,
      frequency: DoseFrequency.twice,
      timing: IntakeTiming.afterMeal,
    );
    final chosen = base.withAppearance(PillShape.capsule, PillColor.orange);
    expect(chosen.pillShape, PillShape.capsule);
    expect(chosen.copyWith(dosePerIntake: 2).pillColor, PillColor.orange);
    expect(chosen.withAppearance(null, null).pillShape, isNull);
  });
}
