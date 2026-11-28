import '../../domain/entities/meal_suggestion.dart';

/// Hạn chế ăn uống và sở thích khai trong app (chưa có chỗ lưu trên server, 01 mục A).
///
/// Chỉ giữ trong bộ nhớ suốt phiên chạy app; không lưu bền. Xóa khi đăng xuất hoặc đổi tài khoản
/// (`app.dart`).
class DietarySession {
  DietarySession._();

  /// Phiên ăn uống cô lập (ví dụ cho từng người bệnh phía người thân — QD-29).
  DietarySession.isolated();

  static final DietarySession instance = DietarySession._();

  DietaryDeclaration? restrictions;
  List<String> preferences = const [];

  bool get isDeclared => restrictions != null;

  void clear() {
    restrictions = null;
    preferences = const [];
  }
}

/// Kiểm danh sách khai báo theo contract: 1–40 ký tự mỗi mục, không trùng, tối đa [max] mục.
/// Trả `null` khi hợp lệ, hoặc câu lỗi để hiển thị.
String? validateDietaryItems(List<String> items, {required int max}) {
  if (items.length > max) return 'Tối đa $max mục.';
  final seen = <String>{};
  for (final raw in items) {
    final item = raw.trim();
    if (item.isEmpty) return 'Mục không được để trống.';
    if (item.length > 40) return 'Mỗi mục tối đa 40 ký tự.';
    if (!seen.add(item.toLowerCase())) return 'Có mục bị trùng.';
  }
  return null;
}
