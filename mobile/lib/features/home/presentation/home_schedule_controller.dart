import 'package:flutter/widgets.dart';

import '../../../core/sync/schedule_sync_service.dart';
import '../../adherence_history/domain/entities/adherence_history.dart';
import '../../adherence_history/domain/repositories/adherence_history_repository.dart';
import '../../adherence_history/domain/schedule_occurrences.dart';
import '../../adherence_history/presentation/utils/adherence_history_format.dart';

enum HomeConfirmation { synced, pending, failed }

class HomeScheduleController extends ChangeNotifier {
  HomeScheduleController(this._history, this._schedules, this._confirm,
      {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final AdherenceHistoryRepository? _history;
  final ScheduleRemoteDataSource? _schedules;
  final Future<HomeConfirmation> Function(String, HistoryDose) _confirm;
  final DateTime Function() clock;
  String? _patient;
  bool _allowed = false;
  int _access = 0, _request = 0;
  bool loading = false, failed = false, saving = false;
  DateHistoryGroup? day;
  int? streak;
  String? message;

  /// Tăng mỗi lần một liều được ghi nhận và đồng bộ xong (sau khi tải lại lịch).
  int confirmedSeq = 0;

  /// Tăng mỗi lần ghi nhận liều thất bại.
  int confirmFailedSeq = 0;

  /// Liều vừa được ghi nhận gần nhất: (scheduleId, scheduledAt UTC).
  (int, DateTime)? lastConfirmed;
  int get accessRevision => _access;
  final _pending = <(int, DateTime)>{};

  bool isPending(HistoryDose dose) =>
      _pending.contains((dose.scheduleId, dose.scheduledAt.toUtc()));

  void setAccess(String? patient, bool allowed) {
    if (_patient == patient && _allowed == allowed) return;
    _patient = patient;
    _allowed = allowed;
    _access++;
    _request++;
    day = null;
    streak = null;
    loading = saving = false;
    failed = !allowed;
    _pending.clear();
    message = null;
    notifyListeners();
  }

  static bool canConfirm(HistoryDose dose, DateTime now) =>
      dose.status == HistoryDoseStatus.pending &&
      !now.isBefore(dose.scheduledAt.subtract(const Duration(minutes: 30))) &&
      !now.isAfter(dose.scheduledAt.add(const Duration(minutes: 120)));

  Future<void> load() async {
    final patient = _patient;
    final history = _history;
    final schedules = _schedules;
    if (!_allowed || patient == null || history == null || schedules == null) {
      failed = true;
      notifyListeners();
      return;
    }
    final request = ++_request;
    final today = HistoryFormat.today(clock());
    loading = true;
    failed = false;
    day = null;
    streak = null;
    notifyListeners();
    try {
      final entries = <DateHistoryGroup>[];
      var end = today;
      int count = 0;
      while (true) {
        final start = end.subtract(const Duration(days: 89));
        final result =
            await history.fetch(from: start, to: end, mode: HistoryMode.date);
        if (request != _request) return;
        if (result.patientId != patient ||
            result.from != start ||
            result.to != end ||
            result.mode != HistoryMode.date) {
          throw StateError('Invalid adherence response');
        }
        entries.addAll(result.dates);
        final byDate = {for (final group in result.dates) group.date: group};
        var date = end;
        if (end == today && !_complete(byDate[today])) {
          date = today.subtract(const Duration(days: 1));
        }
        while (!date.isBefore(start) && _complete(byDate[date])) {
          count++;
          date = date.subtract(const Duration(days: 1));
        }
        if (!date.isBefore(start)) break;
        end = date;
      }
      final rows = await schedules.fetchSchedules(patientId: patient);
      if (request != _request) return;
      day = mergeUpcomingDoses(
        schedules: rows,
        history: entries,
        firstDay: today,
        lastDay: today,
        now: clock(),
      )[today];
      if (day != null) {
        for (final dose in day!.doses) {
          if (dose.status != HistoryDoseStatus.pending) {
            _pending.remove((dose.scheduleId, dose.scheduledAt.toUtc()));
          }
        }
      }
      if (_pending.isEmpty && message == 'Đang chờ đồng bộ') message = null;
      streak = day != null &&
              !_complete(day) &&
              entries.any((group) => group.date == today && _complete(group))
          ? count - 1
          : count;
    } catch (_) {
      if (request == _request) failed = true;
    } finally {
      if (request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  static bool _complete(DateHistoryGroup? group) {
    final summary = group?.summary;
    return summary != null &&
        summary.total > 0 &&
        summary.taken + summary.late == summary.total;
  }

  Future<void> confirm(HistoryDose dose) async {
    final patient = _patient;
    if (!_allowed ||
        patient == null ||
        saving ||
        loading ||
        isPending(dose) ||
        day?.doses.contains(dose) != true ||
        !canConfirm(dose, clock())) {
      return;
    }
    final access = _access;
    saving = true;
    message = null;
    notifyListeners();
    try {
      final outcome = await _confirm(patient, dose);
      if (access != _access) return;
      switch (outcome) {
        case HomeConfirmation.synced:
          await load();
          if (access != _access) return;
          lastConfirmed = (dose.scheduleId, dose.scheduledAt.toUtc());
          confirmedSeq++;
        case HomeConfirmation.pending:
          _pending.add((dose.scheduleId, dose.scheduledAt.toUtc()));
          message = 'Đang chờ đồng bộ';
        case HomeConfirmation.failed:
          message = 'Chưa ghi nhận được liều. Hãy thử lại.';
          confirmFailedSeq++;
      }
    } catch (_) {
      if (access == _access) {
        message = 'Chưa ghi nhận được liều. Hãy thử lại.';
        confirmFailedSeq++;
      }
    } finally {
      if (access == _access) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _access++;
    _request++;
    super.dispose();
  }
}

class HomeScheduleScope extends InheritedNotifier<HomeScheduleController> {
  const HomeScheduleScope(
      {super.key,
      required HomeScheduleController controller,
      required super.child})
      : super(notifier: controller);

  static HomeScheduleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeScheduleScope>()?.notifier;
}
