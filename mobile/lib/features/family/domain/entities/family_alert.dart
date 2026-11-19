// ID từ push là chuỗi số nguyên dương trong miền int64 của backend.
int? familyNotificationId(Object? value) {
  if (value is! String || !RegExp(r'^[0-9]+$').hasMatch(value)) return null;
  final parsed = BigInt.tryParse(value);
  if (parsed == null ||
      parsed <= BigInt.zero ||
      parsed > BigInt.parse('9223372036854775807')) {
    return null;
  }
  return int.tryParse(value);
}

class FamilyAlert {
  const FamilyAlert(
      {required this.id,
      required this.patientId,
      required this.patientName,
      required this.medicationName,
      required this.scheduledAt,
      required this.createdAt,
      required this.content,
      required this.isRead});

  final int id;
  final String? patientId, patientName, medicationName;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final String content;
  final bool isRead;
  // Thiếu snapshot thì hiện nhãn legacy, không suy giờ liều từ createdAt.
  bool get isLegacy => medicationName == null || scheduledAt == null;

  factory FamilyAlert.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid alert');
    }
    const requiredFields = [
      'id',
      'type',
      'title',
      'content',
      'is_read',
      'about_patient_user_id',
      'about_patient_name',
      'created_at',
      'medication_name',
      'scheduled_at'
    ];
    if (!requiredFields.every(value.containsKey) ||
        value['id'] is! int ||
        familyNotificationId('${value['id']}') == null ||
        value['type'] != 'canh_bao_bo_lo_lieu_nguoi_than' ||
        value['title'] is! String ||
        value['content'] is! String ||
        value['is_read'] is! bool) {
      throw const FormatException('Invalid alert');
    }
    String? nullableString(String key) {
      final v = value[key];
      if (v != null && v is! String) {
        throw const FormatException('Invalid field');
      }
      return v as String?;
    }

    // Bắt buộc offset để chuẩn hóa UTC, tránh phụ thuộc múi giờ trên thiết bị.
    DateTime date(Object? v) {
      if (v is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(v)) {
        throw const FormatException('Missing time offset');
      }
      return DateTime.parse(v).toUtc();
    }

    final patient = nullableString('about_patient_user_id');
    if (patient != null &&
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(patient)) {
      throw const FormatException('Invalid patient');
    }
    return FamilyAlert(
        id: value['id'] as int,
        patientId: patient,
        patientName: nullableString('about_patient_name'),
        medicationName: nullableString('medication_name'),
        scheduledAt:
            value['scheduled_at'] == null ? null : date(value['scheduled_at']),
        createdAt: date(value['created_at']),
        content: value['content'] as String,
        isRead: value['is_read'] as bool);
  }

  // Hiển thị cố định UTC+7 theo Asia/Ho_Chi_Minh dù thiết bị ở múi giờ khác.
  String get scheduledTimeVietnam {
    final date = scheduledAt?.toUtc().add(const Duration(hours: 7));
    if (date == null) return 'Không có dữ liệu liều cũ';
    String two(int n) => '$n'.padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)} · ${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class FamilyAlertPage {
  const FamilyAlertPage(this.items, this.total, this.unreadCount);
  final List<FamilyAlert> items;
  final int total, unreadCount;
  factory FamilyAlertPage.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['items'] is! List ||
        value['total'] is! int ||
        value['unread_count'] is! int ||
        (value['total'] as int) < 0 ||
        (value['unread_count'] as int) < 0) {
      throw const FormatException('Invalid inbox');
    }
    return FamilyAlertPage(
        List.unmodifiable((value['items'] as List).map(FamilyAlert.fromJson)),
        value['total'] as int,
        value['unread_count'] as int);
  }
}
