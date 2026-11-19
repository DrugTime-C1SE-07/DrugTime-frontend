import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../../../core/notification/reminder_scheduler.dart';

/// Bộ điều phối lưu và quản lý trạng thái màn hình sửa thông tin thuốc (Task 2.08).
/// Khi người dùng gạt tắt nhắc nhở (`reminder_enabled = false`), tự động hủy các thông báo cũ.
class EditMedicationController {
  EditMedicationController({
    required this.medication,
    required this.medicationRepository,
    this.reminderScheduler,
  }) : reminderEnabled = medication.reminderEnabled;

  final Medication medication;
  final MedicationRepository medicationRepository;
  final ReminderScheduler? reminderScheduler;

  bool reminderEnabled;

  /// Lưu thông tin thuốc đã sửa và xử lý hủy thông báo nhắc nhở nếu tắt.
  Future<Medication> save({
    Medication? updated,
    bool? reminderEnabled,
  }) async {
    final effectiveReminderEnabled = reminderEnabled ?? this.reminderEnabled;
    this.reminderEnabled = effectiveReminderEnabled;

    final base = updated ?? medication;
    final toSave = base.copyWith(reminderEnabled: effectiveReminderEnabled);
    final result = await medicationRepository.update(medication, toSave);

    if (!effectiveReminderEnabled) {
      final scheduleId = int.tryParse(medication.id);
      if (scheduleId != null) {
        await reminderScheduler?.cancelAllForSchedule(scheduleId);
      }
    }

    return result;
  }
}
