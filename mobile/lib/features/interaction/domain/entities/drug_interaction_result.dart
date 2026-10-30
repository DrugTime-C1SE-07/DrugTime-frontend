import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Mức độ nghiêm trọng của tương tác thuốc.
enum InteractionSeverity {
  /// Chống chỉ định (Mức 4) - Tuyệt đối không dùng chung.
  contraindicated(
    label: 'Chống chỉ định',
    levelCode: 'CẤP 1',
    badgeColor: AppColors.danger,
    badgeBackgroundColor: AppColors.dangerBg,
    textColor: AppColors.danger,
  ),

  /// Nghiêm trọng (Mức 3) - Có thể đe dọa tính mạng hoặc tổn thương vĩnh viễn.
  severe(
    label: 'Nghiêm trọng',
    levelCode: 'CẤP 2',
    badgeColor: AppColors.danger,
    badgeBackgroundColor: AppColors.dangerBg,
    textColor: AppColors.danger,
  ),

  /// Trung bình (Mức 2) - Có thể làm suy giảm hiệu quả hoặc tăng tác dụng phụ.
  moderate(
    label: 'Trung bình',
    levelCode: 'CẤP 3',
    badgeColor: AppColors.caution,
    badgeBackgroundColor: AppColors.cautionBg,
    textColor: AppColors.cautionText,
  ),

  /// Nhẹ (Mức 1) - Tác dụng phụ nhẹ, theo dõi lâm sàng.
  mild(
    label: 'Nhẹ',
    levelCode: 'CẤP 4',
    badgeColor: AppColors.info,
    badgeBackgroundColor: AppColors.infoBg,
    textColor: AppColors.info,
  );

  const InteractionSeverity({
    required this.label,
    required this.levelCode,
    required this.badgeColor,
    required this.badgeBackgroundColor,
    required this.textColor,
  });

  final String label;
  final String levelCode;
  final Color badgeColor;
  final Color badgeBackgroundColor;
  final Color textColor;
}

/// Trạng thái kết quả đối soát tương tác thuốc (Tuân thủ CD06).
enum InteractionStatus {
  /// Có tương tác thuốc-thuốc trong cơ sở dữ liệu.
  hasInteractions,

  /// Đã kiểm tra và không tìm thấy tương tác đã biết trong cơ sở dữ liệu.
  /// Tuyệt đối KHÔNG khẳng định là "an toàn".
  noKnownInteractions,

  /// Một số thuốc chưa có dữ liệu hoạt chất để kiểm tra tương tác.
  insufficientData,
}

/// Một cặp tương tác giữa 2 thuốc.
class DrugInteractionPair {
  const DrugInteractionPair({
    required this.firstDrugName,
    required this.secondDrugName,
    required this.severity,
    required this.description,
    this.recommendation,
    this.referenceSource,
  });

  /// Tên biệt dược hoặc hoạt chất thứ nhất.
  final String firstDrugName;

  /// Tên biệt dược hoặc hoạt chất thứ hai.
  final String secondDrugName;

  /// Mức độ nghiêm trọng.
  final InteractionSeverity severity;

  /// Cơ chế hoặc biểu hiện tương tác dược lý.
  final String description;

  /// Khuyến cáo xử trí y tế / hướng dẫn từ dược thư.
  final String? recommendation;

  /// Nguồn tham chiếu (ví dụ: Dược thư Quốc gia Việt Nam).
  final String? referenceSource;
}

/// Báo cáo tổng thể kết quả kiểm tra tương tác thuốc.
class DrugInteractionReport {
  DrugInteractionReport({
    required this.status,
    this.pairs = const [],
    DateTime? timestamp,
    this.insufficientDataMedications = const [],
    List<String>? checkedMedications,
    this.patientName,
  })  : timestamp = timestamp ?? DateTime.now(),
        _checkedMedications = checkedMedications;

  /// Trạng thái tổng quát theo bất biến CD06.
  final InteractionStatus status;

  /// Danh sách tất cả các cặp tương tác tìm thấy (không dừng ở cặp đầu tiên).
  final List<DrugInteractionPair> pairs;

  /// Thời điểm thực hiện đối soát.
  final DateTime timestamp;

  /// Danh sách các thuốc chưa có dữ liệu hoạt chất (nếu status = insufficientData).
  final List<String> insufficientDataMedications;

  /// Tên bệnh nhân / người thân được đối soát (hiển thị trên Patient Banner).
  final String? patientName;

  final List<String>? _checkedMedications;

  /// Kiểm tra xem danh sách thuốc đối soát có được truyền tường minh hay không.
  bool get hasExplicitCheckedMedications =>
      _checkedMedications != null && _checkedMedications.isNotEmpty;

  /// Danh sách các thuốc/hoạt chất đã đối soát.
  List<String> get checkedMedications {
    final list = _checkedMedications;
    if (list != null && list.isNotEmpty) {
      return list;
    }
    final drugs = <String>{};
    for (final p in pairs) {
      drugs.add(p.firstDrugName);
      drugs.add(p.secondDrugName);
    }
    drugs.addAll(insufficientDataMedications);
    return drugs.toList();
  }

  /// Có ít nhất một cặp tương tác thuốc.
  bool get hasInteractions =>
      status == InteractionStatus.hasInteractions && pairs.isNotEmpty;

  /// Đã kiểm tra không thấy tương tác trong dữ liệu hiện tại.
  bool get noKnownInteractions =>
      status == InteractionStatus.noKnownInteractions;

  /// Chưa đủ dữ liệu hoạt chất để kết luận.
  bool get isInsufficientData => status == InteractionStatus.insufficientData;
}
