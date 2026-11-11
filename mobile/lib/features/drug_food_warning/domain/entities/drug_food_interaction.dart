/// Thực thể kết quả kiểm tra tương tác thuốc và thức ăn/đồ uống (CD7, NFR03, Task 4.06).
library;

const String nfr03Disclaimer =
    'DrugTime là hệ thống hỗ trợ quản lý thuốc và cung cấp thông tin tham khảo. '
    'Ứng dụng không thay thế bác sĩ hoặc dược sĩ trong việc ra quyết định lâm sàng.';

/// Mức độ nghiêm trọng của tương tác thuốc - thức ăn (đồng bộ theo Figma S06d).
enum FoodInteractionSeverity {
  contraindicated(1, 'MỨC 1', 'Chống chỉ định'),
  severe(2, 'MỨC 2', 'Nghiêm trọng'),
  moderate(3, 'MỨC 3', 'Thận trọng'),
  minor(4, 'MỨC 4', 'Theo dõi');

  const FoodInteractionSeverity(this.level, this.tag, this.label);

  final int level;
  final String tag;
  final String label;

  static FoodInteractionSeverity fromLevel(int level) {
    for (final s in values) {
      if (s.level == level) return s;
    }
    return minor;
  }
}

/// Trạng thái kiểm tra tương tác thuốc - thức ăn (3 trạng thái chuẩn CD7).
enum FoodInteractionStatus {
  found('co_canh_bao', 'Có cảnh báo tương tác thức ăn'),
  noneFound('da_kiem_tra_khong_thay', 'Đã kiểm tra, không thấy tương tác'),
  insufficientData('khong_du_du_lieu', 'Không đủ dữ liệu đối soát');

  const FoodInteractionStatus(this.code, this.label);

  final String code;
  final String label;

  static FoodInteractionStatus fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return noneFound;
  }
}

/// Một cảnh báo tương tác giữa thuốc và thực phẩm/đồ uống cụ thể.
class FoodWarningItem {
  const FoodWarningItem({
    required this.id,
    required this.medicationName,
    required this.activeIngredient,
    required this.foodName,
    required this.foodCategory,
    required this.severity,
    required this.mechanismAndRisk,
    required this.recommendation,
    this.timingAdvice,
    required this.source,
    this.catalogId,
  });

  final String id;
  final String medicationName;
  final String activeIngredient;
  final String foodName;
  final String foodCategory;
  final FoodInteractionSeverity severity;
  final String mechanismAndRisk;
  final String recommendation;
  final String? timingAdvice;
  final String source;
  final int? catalogId;

  int get severityLevel => severity.level;
  bool get isContraindicated => severity == FoodInteractionSeverity.contraindicated;
}

/// Kết quả kiểm tra tương tác thuốc & thức ăn/đồ uống.
class DrugFoodInteractionResult {
  const DrugFoodInteractionResult({
    required this.status,
    required this.warnings,
    this.insufficientDataMedications = const [],
    this.disclaimer = nfr03Disclaimer,
  });

  final FoodInteractionStatus status;
  final List<FoodWarningItem> warnings;
  final List<String> insufficientDataMedications;
  final String disclaimer;

  bool get hasWarnings => warnings.isNotEmpty;
  bool get isInsufficientData => status == FoodInteractionStatus.insufficientData;
  bool get hasContraindication => warnings.any((w) => w.isContraindicated);

  /// Trả về mức độ nghiêm trọng cao nhất (1: Chống chỉ định là cao nhất, 4: Thấp nhất).
  int get highestSeverityLevel {
    if (warnings.isEmpty) return 0;
    return warnings.map((w) => w.severityLevel).reduce((a, b) => a < b ? a : b);
  }
}
