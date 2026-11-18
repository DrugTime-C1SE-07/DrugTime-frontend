/// Thực thể gợi ý bữa ăn (task 5.11), theo contract `POST /patients/{id}/meal-suggestions`.
///
/// Gợi ý chỉ nằm trong bộ nhớ khi màn đang mở; không lưu bền (response `no-store`).
library;

enum MealType {
  sang('sang', 'Sáng', 'bữa sáng', 'Sáng nay'),
  trua('trua', 'Trưa', 'bữa trưa', 'Trưa nay'),
  toi('toi', 'Tối', 'bữa tối', 'Tối nay');

  const MealType(this.apiValue, this.tabLabel, this.mealLabel, this.todayLabel);

  final String apiValue;
  final String tabLabel;
  final String mealLabel;
  final String todayLabel;

  static MealType fromApi(String value) =>
      values.firstWhere((t) => t.apiValue == value,
          orElse: () => throw FormatException('Unknown meal_type $value'));

  /// Tab mặc định theo giờ Việt Nam: trước 10:00 Sáng, 10:00–15:59 Trưa, từ 16:00 Tối.
  static MealType forVietnamTime(DateTime now) {
    final hour = now.toUtc().add(const Duration(hours: 7)).hour;
    if (hour < 10) return sang;
    if (hour < 16) return trua;
    return toi;
  }
}

enum MealDishType {
  com('com', 'Cơm'),
  monNuoc('mon_nuoc', 'Món nước'),
  monMan('mon_man', 'Món mặn'),
  monXao('mon_xao', 'Món xào'),
  monHapLuoc('mon_hap_luoc', 'Hấp/luộc'),
  chaoSup('chao_sup', 'Cháo/súp'),
  salad('salad', 'Salad'),
  khac('khac', 'Khác');

  const MealDishType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Giá trị chưa biết (phiên bản sau thêm) xử lý như `khac` (contract).
  static MealDishType fromApi(String? value) =>
      values.firstWhere((t) => t.apiValue == value, orElse: () => khac);
}

class MealBenefit {
  const MealBenefit({required this.text, required this.type, this.label});

  final String text;

  /// `condition` | `allergy` | `restriction` | `general`.
  final String type;

  /// Nhãn hiển thị (tên bệnh nền, dị ứng, hạn chế); `null` khi `general`. Không bao giờ là tên thuốc.
  final String? label;
}

class MealIngredient {
  const MealIngredient({
    required this.name,
    required this.amount,
    required this.isMain,
    required this.useSparingly,
  });

  final String name;
  final String amount;
  final bool isMain;
  final bool useSparingly;
}

enum MealImageStatus { pending, ready, failed }

class MealImageAttribution {
  const MealImageAttribution({
    required this.photographerName,
    required this.photographerUrl,
    required this.sourceUrl,
  });

  final String photographerName;
  final String photographerUrl;
  final String sourceUrl;
}

class MealDishImage {
  const MealDishImage({
    required this.imageId,
    required this.status,
    this.url,
    this.attribution,
  });

  final int imageId;
  final MealImageStatus status;

  /// Đường dẫn tương đối trên Backend API, ví dụ `/meal-images/42`.
  final String? url;
  final MealImageAttribution? attribution;

  bool get isReady => status == MealImageStatus.ready && url != null;
}

class MealDish {
  const MealDish({
    required this.name,
    required this.dishType,
    required this.isNew,
    required this.tags,
    required this.kcalEstimate,
    required this.cookMinutes,
    required this.image,
    required this.benefits,
    required this.ingredients,
  });

  final String name;
  final MealDishType dishType;
  final bool isNew;
  final List<String> tags;
  final int kcalEstimate;
  final int cookMinutes;

  /// `null`: món sẽ không có ảnh, app dùng ảnh mặc định và không hỏi lại.
  final MealDishImage? image;
  final List<MealBenefit> benefits;
  final List<MealIngredient> ingredients;

  List<MealIngredient> get mainIngredients =>
      ingredients.where((i) => i.isMain).toList();
  List<MealIngredient> get seasonings =>
      ingredients.where((i) => !i.isMain).toList();
}

enum FoodCheckStatus { coTuongTac, daKiemTraKhongThay, khongDuDuLieu }

class MealFoodWarning {
  const MealFoodWarning({
    required this.foodToAvoid,
    required this.reason,
    required this.severityLevel,
    required this.source,
  });

  final String foodToAvoid;
  final String reason;
  final int severityLevel;
  final String source;
}

class MealFoodCheck {
  const MealFoodCheck({required this.status, required this.warnings});

  final FoodCheckStatus status;
  final List<MealFoodWarning> warnings;
}

class MealSuggestionResult {
  const MealSuggestionResult({
    required this.suggestionId,
    required this.mealType,
    required this.dishes,
    required this.foodCheck,
    required this.disclaimer,
    required this.refreshesRemaining,
    required this.createdAt,
  });

  final int suggestionId;
  final MealType mealType;
  final List<MealDish> dishes;
  final MealFoodCheck foodCheck;
  final String disclaimer;
  final int refreshesRemaining;
  final DateTime createdAt;
}

/// Khai báo bắt buộc (QD-40): `none` = người dùng xác nhận không có.
class DietaryDeclaration {
  const DietaryDeclaration.none()
      : none = true,
        items = const [];
  const DietaryDeclaration.items(this.items) : none = false;

  final bool none;
  final List<String> items;

  Map<String, Object> toJson() => {'none': none, 'items': items};
}

enum MealFailureKind {
  llmDisabled,
  llmUnavailable,
  llmInvalidOutput,
  serviceUnavailable,
  forbidden,
  consentRevoked,
  previousNotFound,
  refreshLimit,
  network,
  unknown,
}

class MealSuggestionFailure implements Exception {
  const MealSuggestionFailure(this.kind);

  final MealFailureKind kind;

  /// `llm_disabled` không có nút "Thử lại" (AC18).
  bool get canRetry =>
      kind != MealFailureKind.llmDisabled &&
      kind != MealFailureKind.forbidden &&
      kind != MealFailureKind.consentRevoked;

  String get message => switch (kind) {
        MealFailureKind.llmDisabled =>
          'Tính năng gợi ý bữa ăn đang tạm ngưng.',
        MealFailureKind.llmUnavailable ||
        MealFailureKind.serviceUnavailable =>
          'Chưa tạo được gợi ý lúc này. Bạn thử lại sau ít phút nhé.',
        MealFailureKind.llmInvalidOutput =>
          'Gợi ý chưa đạt yêu cầu kiểm tra. Bạn thử lại nhé.',
        MealFailureKind.forbidden ||
        MealFailureKind.consentRevoked =>
          'Bạn cần bật gợi ý bữa ăn để xem gợi ý.',
        MealFailureKind.previousNotFound =>
          'Không tìm thấy gợi ý trước. Đang tạo gợi ý mới.',
        MealFailureKind.refreshLimit =>
          'Hôm nay bạn đã dùng hết lượt gợi ý khác.',
        MealFailureKind.network =>
          'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        MealFailureKind.unknown => 'Đã có lỗi xảy ra. Bạn thử lại nhé.',
      };

  @override
  String toString() => 'MealSuggestionFailure($kind)';
}
