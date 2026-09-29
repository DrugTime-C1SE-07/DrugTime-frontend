import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
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
}
