import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/home/presentation/home_schedule_controller.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/home_pet_signals.dart';
import 'package:flutter_test/flutter_test.dart';

/// 08:00 giờ Việt Nam ngày 2026-11-17.
final _at8 = DateTime.utc(2026, 11, 17, 1);

HistoryDose _dose(int id, int hourIct, HistoryDoseStatus status) => HistoryDose(
      medicationId: id,
      medicationName: 'Thuốc $id',
      scheduleId: id,
      scheduledAt: DateTime.utc(2026, 11, 17, hourIct - 7),
      takenAt: null,
      status: status,
      statusSource: 'test',
    );

HomeScheduleController _controller(List<HistoryDose> doses) {
  int n(HistoryDoseStatus s) => doses.where((d) => d.status == s).length;
  return HomeScheduleController(
      null, null, (_, __) async => HomeConfirmation.synced)
    ..day = DateHistoryGroup(
        DateTime.utc(2026, 11, 17),
        AdherenceSummary(
            total: doses.length,
            taken: n(HistoryDoseStatus.taken),
            late: n(HistoryDoseStatus.late),
            missed: n(HistoryDoseStatus.missed),
            pending: n(HistoryDoseStatus.pending),
            counted: doses.length,
            rate: null),
        doses)
    ..streak = 7;
}

void main() {
  test(
      'pha đêm theo giờ Việt Nam, kể cả khi thời điểm truyền vào là giờ địa phương (AC12)',
      () {
    NightPhase at(int h, int m) => HomePetSignals(
            ictMinutes: HomePetSignals.minutesOf(
                DateTime.utc(2026, 11, 17, h, m).toLocal()))
        .phase;
    // 15:00 UTC = 22:00 ICT
    expect(at(15, 0), NightPhase.asleep);
    expect(at(14, 59), NightPhase.yawning);
    expect(at(14, 30), NightPhase.yawning);
    expect(at(14, 29), NightPhase.awake);
    // 22:29 UTC = 05:29 ICT hôm sau
    expect(at(22, 29), NightPhase.asleep);
    expect(at(22, 30), NightPhase.awake);
  });

  test('cửa sổ liều dùng đúng biên -30/+120 phút của canConfirm (AC7, QD-01)',
      () {
    final c = _controller([_dose(1, 8, HistoryDoseStatus.pending)]);
    bool window(Duration offset) =>
        HomePetSignals.from(c, _at8.add(offset)).inDoseWindow;
    expect(window(const Duration(minutes: -31)), isFalse);
    expect(window(const Duration(minutes: -30)), isTrue);
    expect(window(const Duration(minutes: 120)), isTrue);
    expect(window(const Duration(minutes: 121)), isFalse);
  });

  test('bỏ lỡ, xong ngày và chuỗi (AC8, AC20)', () {
    final missed = HomePetSignals.from(
        _controller([
          _dose(1, 6, HistoryDoseStatus.missed),
          _dose(2, 7, HistoryDoseStatus.taken),
        ]),
        _at8);
    expect(missed.missedToday, isTrue);
    expect(missed.allDone, isFalse);
    expect(missed.remaining, isTrue);
    expect(missed.streak, 7);

    final done = HomePetSignals.from(
        _controller([
          _dose(1, 6, HistoryDoseStatus.late),
          _dose(2, 7, HistoryDoseStatus.taken),
        ]),
        _at8);
    expect(done.allDone, isTrue);
    expect(done.missedToday, isFalse);
    expect(done.remaining, isFalse);
  });

  test('không có controller: chỉ còn giờ và cờ chưa có thuốc', () {
    final s = HomePetSignals.from(null, _at8, empty: true);
    expect(s.empty, isTrue);
    expect(s.inDoseWindow || s.allDone || s.failed, isFalse);
    expect(s.ictMinutes, 8 * 60);
  });
}
