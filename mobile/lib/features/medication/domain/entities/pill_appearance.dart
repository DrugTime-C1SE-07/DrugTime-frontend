import 'dart:ui' show Color;

/// Hình người bệnh chọn để nhận ra thuốc (S07-M2b). Chỉ để hiển thị: không thay dạng bào chế
/// của danh mục, không dùng cho đơn vị liều hay kiểm tra tương tác. [apiValue] khớp enum
/// `PillShape` của api_contract.
enum PillShape {
  capsule('capsule', 'Viên nang'),
  roundTablet('round_tablet', 'Viên tròn'),
  oblongTablet('oblong_tablet', 'Viên dài'),
  softgel('softgel', 'Nang mềm'),
  effervescent('effervescent', 'Viên sủi'),
  powderSachet('powder_sachet', 'Gói bột'),
  syrup('syrup', 'Siro'),
  drops('drops', 'Thuốc nhỏ'),
  spray('spray', 'Thuốc xịt'),
  injectionPen('injection_pen', 'Bút tiêm'),
  topical('topical', 'Thuốc bôi');

  const PillShape(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// `null` khi server trả giá trị app chưa biết (enum thêm sau): hiển thị như chưa chọn.
  static PillShape? fromApi(Object? value) {
    for (final shape in values) {
      if (shape.apiValue == value) return shape;
    }
    return null;
  }

  /// Hình gợi ý từ dạng bào chế của danh mục, dùng làm lựa chọn mặc định ở M2b.
  static PillShape suggestFor(String? dosageForm) {
    final s = (dosageForm ?? '').toLowerCase();
    bool has(List<String> words) => words.any(s.contains);
    if (has(['nang mềm', 'softgel'])) return PillShape.softgel;
    if (has(['nang', 'capsule'])) return PillShape.capsule;
    if (has(['sủi', 'effervescent'])) return PillShape.effervescent;
    if (has(['bột', 'cốm', 'gói', 'powder', 'sachet'])) {
      return PillShape.powderSachet;
    }
    if (has(['siro', 'syrup', 'dung dịch', 'hỗn dịch', 'nhũ dịch'])) {
      return PillShape.syrup;
    }
    if (has(['nhỏ', 'drop', 'giọt'])) return PillShape.drops;
    if (has(['xịt', 'spray', 'khí dung'])) return PillShape.spray;
    if (has(['tiêm', 'inject'])) return PillShape.injectionPen;
    if (has(['bôi', 'kem', 'gel', 'mỡ', 'cream', 'ointment'])) {
      return PillShape.topical;
    }
    if (has(['dài', 'oblong'])) return PillShape.oblongTablet;
    return PillShape.roundTablet;
  }
}

/// Màu người bệnh chọn cho thuốc. [apiValue] khớp enum `PillColor` của api_contract.
enum PillColor {
  white('white', 'Trắng', Color(0xFFF4F4F1)),
  yellow('yellow', 'Vàng', Color(0xFFF2D35B)),
  orange('orange', 'Cam', Color(0xFFF0A257)),
  pink('pink', 'Hồng', Color(0xFFF2B3C2)),
  red('red', 'Đỏ', Color(0xFFD9534F)),
  brown('brown', 'Nâu', Color(0xFFA0714F)),
  blue('blue', 'Xanh lam', Color(0xFF7DB4E6)),
  green('green', 'Xanh lá', Color(0xFF8CC79A)),
  purple('purple', 'Tím', Color(0xFFB79AD9)),
  gray('gray', 'Xám', Color(0xFFB8BCC0));

  const PillColor(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static PillColor? fromApi(Object? value) {
    for (final color in values) {
      if (color.apiValue == value) return color;
    }
    return null;
  }
}
