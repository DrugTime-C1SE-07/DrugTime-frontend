import 'package:flutter/painting.dart';

import '../../../../shared/widgets/mascot/mascot_controller.dart';

/// Trạng thái của cảnh "Khu vườn chăm sóc". Cảnh chỉ trang trí: trạng thái do màn hình
/// tính từ dữ liệu thật truyền vào, cảnh không tự đổi trạng thái hay gọi API.
enum GardenMood {
  /// Chưa theo dõi ai: chậu đất trống.
  empty,

  /// Hôm nay ổn.
  ok,

  /// Có liều bỏ lỡ / quá giờ chưa nhắc.
  missed,

  /// Vừa gửi nhắc.
  nudged,

  /// Đã uống bù / đủ liều sau khi nhắc.
  recovered,

  /// Không còn được xem dữ liệu.
  lost,
}

/// Dáng cây trong chậu, đi theo dữ liệu (không đổi khi người dùng chạm).
enum PlantShape { emptyPot, bloom, droop, revive }

/// Đạo cụ phụ trong cảnh.
enum GardenProp { magnifier, pill, bell, paperPlane, wateringCan, confetti }

/// Mô tả tĩnh của một trạng thái: tư thế hai linh vật, dáng cây, màu nền, đạo cụ.
///
/// Hai linh vật ngang hàng: [left] (xanh, mũ làm vườn) và [right] (cam, khăn quàng).
class GardenSpec {
  const GardenSpec({
    required this.left,
    required this.right,
    required this.plant,
    required this.sky,
    required this.ground,
    this.leftProps = const {},
    this.rightProps = const {},
    this.confetti = false,
    this.label = '',
  });

  final MascotMood left, right;
  final PlantShape plant;

  /// Gradient nền (trên → dưới) và màu cỏ.
  final List<Color> sky;
  final Color ground;
  final Set<GardenProp> leftProps, rightProps;
  final bool confetti;

  /// Mô tả cho trình đọc màn hình.
  final String label;
}

const gardenSpecs = <GardenMood, GardenSpec>{
  GardenMood.empty: GardenSpec(
    left: MascotMood.thinking,
    right: MascotMood.wave,
    plant: PlantShape.emptyPot,
    sky: [Color(0xFFEDE7FB), Color(0xFFF7F4FD)],
    ground: Color(0xFFBFE3C4),
    leftProps: {GardenProp.magnifier},
    label: 'Hai bạn thuốc đang chờ bạn thêm người thân',
  ),
  GardenMood.ok: GardenSpec(
    left: MascotMood.idle,
    right: MascotMood.idle,
    plant: PlantShape.bloom,
    sky: [Color(0xFFE8E2FA), Color(0xFFE3F6EE)],
    ground: Color(0xFFA9DDB0),
    label: 'Hai bạn thuốc đang vui vẻ, cây nở hoa',
  ),
  GardenMood.missed: GardenSpec(
    // nghiêng đầu suy nghĩ thay vì `concerned` (mếu, đổ mồ hôi): hai bạn luôn vui vẻ
    left: MascotMood.thinking,
    right: MascotMood.sleepy,
    plant: PlantShape.droop,
    sky: [Color(0xFFFFE6D6), Color(0xFFFFF3EA)],
    ground: Color(0xFFCFE3B5),
    leftProps: {GardenProp.pill},
    label: 'Một bạn thuốc ngủ gật, bạn kia mang thuốc tới',
  ),
  GardenMood.nudged: GardenSpec(
    left: MascotMood.wave,
    right: MascotMood.poke,
    plant: PlantShape.droop,
    sky: [Color(0xFFFFF2C9), Color(0xFFFFF9E8)],
    ground: Color(0xFFC6E3B0),
    leftProps: {GardenProp.bell, GardenProp.paperPlane},
    label: 'Đã rung chuông nhắc bạn thuốc dậy uống thuốc',
  ),
  GardenMood.recovered: GardenSpec(
    left: MascotMood.celebrate,
    right: MascotMood.celebrate,
    plant: PlantShape.revive,
    sky: [Color(0xFFDDF5E3), Color(0xFFF0FBF3)],
    ground: Color(0xFF9AD8A6),
    leftProps: {GardenProp.wateringCan},
    rightProps: {GardenProp.pill},
    confetti: true,
    label: 'Đã uống thuốc, hai bạn thuốc ăn mừng, cây vươn lên',
  ),
  GardenMood.lost: GardenSpec(
    left: MascotMood.wave,
    right: MascotMood.wave,
    plant: PlantShape.bloom,
    sky: [Color(0xFFECEAF3), Color(0xFFF6F5FA)],
    ground: Color(0xFFC9DCCB),
    label: 'Hai bạn thuốc vẫy tay tạm biệt',
  ),
};
