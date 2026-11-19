import '../../../core/api/api_exception.dart';
import '../../../core/storage/local_db/local_medication_store.dart';
import '../../../core/storage/local_db/local_models.dart';
import '../../reminder/domain/entities/dose_reminder.dart';
import '../data/patient_dose_reminder_repository.dart';

/// Kết quả chuẩn bị mở lời nhắc từ người thân (P1).
sealed class CaregiverReminderLaunch {
  const CaregiverReminderLaunch();
}

/// Mở màn nhắc toàn phần (một thuốc) ở chế độ "<người thân> nhắc bạn".
final class OpenDoseReminder extends CaregiverReminderLaunch {
  const OpenDoseReminder(this.group, this.sender);
  final DoseReminderGroup group;
  final String sender;
}

/// Mở hộp thư lời nhắc (chi tiết [reminderId]): liều đã ghi nhận, chưa có lịch trên máy,
/// hoặc không đọc được lời nhắc. Hộp thư tự hiện trạng thái / lỗi tương ứng.
final class OpenReceivedReminder extends CaregiverReminderLaunch {
  const OpenReceivedReminder(this.reminderId, this.reason);
  final int reminderId;
  final String reason;
}

/// Chuẩn bị P1 khi người bệnh chạm thông báo `type=dose_reminder`.
///
/// Xác nhận "Đã uống" đi qua luồng nhắc thuốc có sẵn (outbox cục bộ, idempotent theo
/// `(medication_schedule_id, scheduled_at)` và `client_uuid`); launcher không ghi liều.
class CaregiverReminderLauncher {
  CaregiverReminderLauncher({required this.repository, required this.store});

  final PatientDoseReminderRepository repository;
  final LocalMedicationStore? store;

  Future<CaregiverReminderLaunch> prepare(int reminderId) async {
    final Map<String, dynamic> detail;
    try {
      detail = await repository.detail(reminderId);
    } on ApiException {
      return OpenReceivedReminder(reminderId, 'detail_failed');
    } on FormatException {
      return OpenReceivedReminder(reminderId, 'detail_invalid');
    } on TypeError {
      // payload không đúng kiểu (vd. không phải object JSON)
      return OpenReceivedReminder(reminderId, 'detail_invalid');
    }
    final scheduleId = detail['schedule_id'];
    final rawAt = detail['scheduled_at'];
    if (scheduleId is! int || rawAt is! String) {
      return OpenReceivedReminder(reminderId, 'detail_invalid');
    }
    final scheduledAt = DateTime.tryParse(rawAt)?.toUtc();
    if (scheduledAt == null) {
      return OpenReceivedReminder(reminderId, 'detail_invalid');
    }
    final rawSender = detail['sender_name'];
    final sender = rawSender is String ? rawSender.trim() : null;

    try {
      await repository.markRead(reminderId);
    } on ApiException {
      // Không chặn việc mở lời nhắc: hộp thư vẫn hiện "chưa đọc" và đánh dấu lại khi mở.
    }

    final local = store;
    if (local == null) return OpenReceivedReminder(reminderId, 'no_store');
    final LocalMedicationSchedule? schedule;
    final bool recorded;
    try {
      schedule = await local.getScheduleById(scheduleId);
      recorded = schedule != null &&
          await local.hasDoseLog(
              medicationScheduleId: scheduleId, scheduledAt: scheduledAt);
    } on Exception {
      // DB cục bộ lỗi (vd. khóa / mã hóa): không đoán trạng thái liều, mở hộp thư.
      return OpenReceivedReminder(reminderId, 'local_store_failed');
    }
    if (schedule == null) {
      return OpenReceivedReminder(reminderId, 'no_local_schedule');
    }
    if (recorded) {
      return OpenReceivedReminder(reminderId, 'already_recorded');
    }
    final dosage = schedule.strengthText != null
        ? '${schedule.quantityPerDose} viên · ${schedule.strengthText}'
        : '${schedule.quantityPerDose} viên';
    return OpenDoseReminder(
      DoseReminderGroup([
        DoseReminderItem(
          medicationScheduleId: scheduleId,
          scheduledAt: scheduledAt,
          medicationName: schedule.medicationName,
          dosageText: dosage,
          instruction: schedule.dosageForm ?? 'Đúng giờ',
        ),
      ]),
      sender == null || sender.isEmpty ? 'Người thân' : sender,
    );
  }
}
