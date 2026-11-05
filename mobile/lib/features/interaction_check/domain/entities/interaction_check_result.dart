/// Thực thể kết quả kiểm tra tương tác thuốc (CD7, NFR03).
library;

const String nfr03Disclaimer =
    'DrugTime là hệ thống hỗ trợ quản lý thuốc và cung cấp thông tin tham khảo. '
    'Ứng dụng không thay thế bác sĩ hoặc dược sĩ trong việc ra quyết định lâm sàng.';

enum InteractionCheckStatus {
  found('co_tuong_tac', 'Có tương tác thuốc'),
  noneFound('da_kiem_tra_khong_thay', 'Đã kiểm tra, không thấy tương tác'),
  insufficientData('khong_du_du_lieu', 'Không đủ dữ liệu hoạt chất');

  const InteractionCheckStatus(this.code, this.label);

  final String code;
  final String label;

  static InteractionCheckStatus fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return noneFound;
  }
}

class InteractionFinding {
  const InteractionFinding({
    required this.ingredientAId,
    required this.ingredientAName,
    this.ingredientBId,
    required this.ingredientBName,
    this.medicationAId,
    this.medicationAName,
    this.medicationBId,
    this.medicationBName,
    required this.severityLevel,
    required this.interactionType,
    required this.handlingType,
    this.minIntervalHours,
    required this.description,
    required this.warningMessage,
    required this.source,
  });

  final int ingredientAId;
  final String ingredientAName;
  final int? ingredientBId;
  final String ingredientBName;
  final int? medicationAId;
  final String? medicationAName;
  final int? medicationBId;
  final String? medicationBName;

  /// 1 = Cần theo dõi, 2 = Cần thận trọng, 3 = Cân nhắc lợi ích/nguy cơ, 4 = Chống chỉ định
  final int severityLevel;
  final String interactionType;
  final String handlingType;
  final double? minIntervalHours;
  final String description;
  final String warningMessage;
  final String source;

  bool get isContraindicated => severityLevel == 4;
}

class InsufficientDataMedication {
  const InsufficientDataMedication({
    required this.medicationId,
    required this.medicationName,
    required this.reason,
  });

  final int medicationId;
  final String medicationName;
  final String reason;
}

class InteractionCheckResult {
  const InteractionCheckResult({
    required this.status,
    required this.interactions,
    this.insufficientDataMedications = const [],
    this.disclaimer = nfr03Disclaimer,
  });

  final InteractionCheckStatus status;
  final List<InteractionFinding> interactions;
  final List<InsufficientDataMedication> insufficientDataMedications;
  final String disclaimer;

  bool get hasInteractions => interactions.isNotEmpty;
  bool get isInsufficientData => status == InteractionCheckStatus.insufficientData;
  int get maxSeverity => interactions.isEmpty
      ? 0
      : interactions.map((i) => i.severityLevel).reduce((a, b) => a > b ? a : b);
  bool get hasContraindication => maxSeverity == 4;
}
