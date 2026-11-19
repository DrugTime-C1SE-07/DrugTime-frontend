import 'package:drugtime_mobile/features/family_link/presentation/garden/garden_mood.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mọi trạng thái đều có mô tả cảnh (AC15)', () {
    for (final mood in GardenMood.values) {
      final spec = gardenSpecs[mood];
      expect(spec, isNotNull, reason: mood.name);
      expect(spec!.sky.length, 2, reason: mood.name);
      expect(spec.label, isNotEmpty, reason: mood.name);
    }
  });

  test('dáng cây đi theo trạng thái dữ liệu', () {
    expect(gardenSpecs[GardenMood.empty]!.plant, PlantShape.emptyPot);
    expect(gardenSpecs[GardenMood.ok]!.plant, PlantShape.bloom);
    expect(gardenSpecs[GardenMood.missed]!.plant, PlantShape.droop);
    expect(gardenSpecs[GardenMood.nudged]!.plant, PlantShape.droop);
    expect(gardenSpecs[GardenMood.recovered]!.plant, PlantShape.revive);
  });

  test('bỏ lỡ: một bạn ngủ gật, bạn kia mang thuốc; nhắc: rung chuông', () {
    final missed = gardenSpecs[GardenMood.missed]!;
    expect(missed.right, MascotMood.sleepy);
    expect(missed.leftProps, contains(GardenProp.pill));
    final nudged = gardenSpecs[GardenMood.nudged]!;
    expect(nudged.leftProps, contains(GardenProp.bell));
    expect(nudged.right, MascotMood.poke);
  });

  test('uống bù: cả hai ăn mừng, có bình tưới và confetti', () {
    final spec = gardenSpecs[GardenMood.recovered]!;
    expect(spec.left, MascotMood.celebrate);
    expect(spec.right, MascotMood.celebrate);
    expect(spec.leftProps, contains(GardenProp.wateringCan));
    expect(spec.confetti, isTrue);
  });

  test('hai linh vật luôn vui vẻ: không dùng tư thế mếu, che mắt hay ẩn', () {
    for (final spec in gardenSpecs.values) {
      for (final mood in [spec.left, spec.right]) {
        expect(
            mood,
            isNot(anyOf(
                MascotMood.concerned, MascotMood.cover, MascotMood.hidden)));
      }
    }
  });
}
