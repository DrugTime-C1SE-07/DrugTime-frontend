import 'package:drugtime_mobile/features/medication/domain/entities/dose_unit.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DoseTime định dạng 24h và sắp xếp theo giờ trong ngày', () {
    final times = [const DoseTime(20, 0), const DoseTime(7, 5), const DoseTime(12, 30)]..sort();
    expect(times.map((t) => t.format()), ['07:05', '12:30', '20:00']);
  });

  test('Chỉ thuốc đang dùng và tồn kho ≤ ngưỡng mới là sắp hết', () {
    Medication med({int? stock, MedicationStatus status = MedicationStatus.active}) => Medication(
          id: 'x',
          catalogId: 'x',
          name: 'X',
          activeIngredient: 'X',
          strength: '1 mg',
          unit: 'viên',
          dosePerIntake: 1,
          frequency: DoseFrequency.once,
          timing: IntakeTiming.anytime,
          stockRemaining: stock,
          status: status,
        );

    expect(med(stock: Medication.lowStockThreshold).isLowStock, isTrue);
    expect(med(stock: Medication.lowStockThreshold + 1).isLowStock, isFalse);
    expect(med().isLowStock, isFalse);
    expect(med(stock: 1, status: MedicationStatus.stopped).isLowStock, isFalse);
  });

  test('Tần suất "Khi cần" không có giờ nhắc mặc định', () {
    expect(DoseFrequency.asNeeded.defaultTimes, isEmpty);
    expect(DoseFrequency.thrice.defaultTimes, hasLength(3));
  });

  group('doseUnitFor suy đơn vị từ dạng bào chế', () {
    const cases = {
      'Viên nén bao phim': 'viên',
      'Viên nang cứng': 'viên',
      'Nang mềm': 'viên',
      'Thuốc cốm sủi bọt (gói)': 'gói',
      'Thuốc bột uống': 'gói',
      'Ống tiêm': 'ống',
      'Dung dịch uống': 'ml',
      'Siro': 'ml',
      'Thuốc bột pha hỗn dịch uống': 'ml', // hỗn dịch đứng trước bột
      'Nhũ dịch': 'ml',
      'Lọ 100 viên': 'lọ', // lọ đứng trước viên
      'Chai': 'lọ',
      'Dung dịch uống (lọ 60 ml)': 'ml', // dung dịch đứng trước lọ
      'Kem bôi da': 'lần bôi',
      'Gel': 'lần bôi',
      'Thuốc mỡ': 'lần bôi',
      'Thuốc xịt mũi': 'nhát xịt',
      'Thuốc nhỏ mắt': 'giọt',
      'VIÊN NÉN': 'viên', // không phân biệt hoa thường
      'vien nen': 'viên', // không dấu
      'Miếng dán': fallbackDoseUnit,
      '': fallbackDoseUnit,
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" → ${entry.value}', () {
        expect(doseUnitFor(entry.key), entry.value);
      });
    }

    test('null → liều', () => expect(doseUnitFor(null), fallbackDoseUnit));

    test('so theo cả từ: "lo" không khớp trong "lop", "mo" không khớp trong "mot"', () {
      expect(doseUnitFor('Lớp phủ một lần'), fallbackDoseUnit);
    });
  });

  test('Tần suất theo số giờ; 4–6 giờ là custom và không có trong danh sách chọn', () {
    expect(DoseFrequency.forTimeCount(1), DoseFrequency.once);
    expect(DoseFrequency.forTimeCount(3), DoseFrequency.thrice);
    expect(DoseFrequency.forTimeCount(5), DoseFrequency.custom);
    expect(DoseFrequency.selectable, isNot(contains(DoseFrequency.custom)));
  });

  test('Định dạng liều số lẻ và nhãn tần suất custom', () {
    expect(formatQuantity(1), '1');
    expect(formatQuantity(2.0), '2');
    expect(formatQuantity(0.5), '0,5');
    expect(formatQuantity(1.25), '1,25');

    const med = Medication(
      id: '1',
      catalogId: '1',
      name: 'X',
      activeIngredient: '',
      strength: '',
      unit: 'viên',
      dosePerIntake: 0.5,
      frequency: DoseFrequency.custom,
      timing: IntakeTiming.anytime,
      times: [DoseTime(6, 0), DoseTime(10, 0), DoseTime(14, 0), DoseTime(18, 0)],
    );
    expect(med.doseLabel, '0,5 viên');
    expect(med.frequencyLabel, '4 lần/ngày');
    expect(med.maxDosesLabel, isNull);
    expect(drugSubtitle('', 'Viên nén'), 'Chưa có thông tin hoạt chất · Viên nén');
    expect(drugSubtitle('Paracetamol', null), 'Paracetamol');
  });
}
