import 'package:flutter/widgets.dart';

import '../../domain/entities/adherence_history.dart';
import '../../domain/entities/adherence_history_failure.dart';
import '../../domain/repositories/adherence_history_repository.dart';
import '../utils/adherence_history_format.dart';

class AdherenceHistoryController extends ChangeNotifier {
  AdherenceHistoryController(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    selectedDay = today;
    selectedMonth = HistoryFormat.month(selectedDay);
  }

  final AdherenceHistoryRepository? _repository;
  final DateTime Function() _clock;
  late DateTime selectedMonth;
  HistoryMode mode = HistoryMode.date;
  late DateTime selectedDay;
  final Set<int> _expanded = {};
  AdherenceHistory? history;
  HistoryFailure? error;
  bool loading = false;
  String? _patientId;
  int _generation = 0;
  int _accessRevision = 0;
  int _contentRevision = 0;
  bool _disposed = false;
  bool _revoked = false;

  DateTime get today => HistoryFormat.today(_clock());
  bool get canGoNext => selectedMonth.isBefore(HistoryFormat.month(today));
  bool get canGoPrevious => selectedMonth.year > 1 || selectedMonth.month > 1;
  bool expanded(int id) => _expanded.contains(id);
  int get generation => _generation;
  int get accessRevision => _accessRevision;
  int get contentRevision => _contentRevision;
  DateHistoryGroup? get selectedGroup => dayGroup(selectedDay);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setPatient(String? id) {
    if (_patientId == id) return;
    clear();
    _patientId = id;
    mode = HistoryMode.date;
    selectedDay = today;
    selectedMonth = HistoryFormat.month(today);
    _revoked = false;
    _notify();
  }

  void clear() {
    _accessRevision++;
    mode = HistoryMode.date;
    _invalidateRead();
    _notify();
  }

  void _invalidateRead() {
    _contentRevision++;
    _generation++;
    history = null;
    error = null;
    _expanded.clear();
    loading = false;
  }

  void deactivate() {
    clear();
  }

  void revoke() {
    _revoked = true;
    clear();
    error = const HistoryFailure(HistoryFailureKind.consent);
    _notify();
  }

  /// Local consent grants never authorize cached data: the next load calls PEP.
  void allowFreshRead() {
    _revoked = false;
    _notify();
  }

  Future<void> load() async {
    if (_disposed) return;
    _invalidateRead();
    if (_revoked) {
      error = const HistoryFailure(HistoryFailureKind.consent);
      _notify();
      return;
    }
    if (_patientId == null) {
      error = const HistoryFailure(HistoryFailureKind.unauthorized);
      _notify();
      return;
    }
    if (_repository == null) {
      error = const HistoryFailure(HistoryFailureKind.unconfigured);
      _notify();
      return;
    }
    if (selectedMonth.isAfter(HistoryFormat.month(today))) {
      selectedMonth = HistoryFormat.month(today);
      selectedDay = today;
    }
    if (selectedDay.isAfter(today)) selectedDay = today;
    if (HistoryFormat.month(selectedDay) != selectedMonth) {
      selectedDay = selectedMonth;
    }
    final request = _generation;
    final patient = _patientId;
    final requestedMode = mode;
    final range = HistoryFormat.period(selectedMonth, _clock());
    loading = true;
    _notify();
    try {
      final result = await _repository.fetch(
          from: range.from, to: range.to, mode: requestedMode);
      if (_disposed || request != _generation) return;
      if (result.patientId != patient ||
          result.mode != requestedMode ||
          result.from != range.from ||
          result.to != range.to) {
        throw const HistoryFailure(HistoryFailureKind.invalidResponse);
      }
      history = result;
    } on HistoryFailure catch (failure) {
      if (_disposed || request != _generation) return;
      history = null;
      error = failure;
      if (failure.removesAccess) {
        _accessRevision++;
        mode = HistoryMode.date;
      }
    } finally {
      if (!_disposed && request == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> changeMonth(int delta) async {
    final target =
        DateTime.utc(selectedMonth.year, selectedMonth.month + delta);
    if (target.year < 1 || target.isAfter(HistoryFormat.month(today))) return;
    selectedMonth = target;
    selectedDay = target == HistoryFormat.month(today) ? today : target;
    await load();
  }

  Future<void> changeMode(HistoryMode value) async {
    if (mode == value) return;
    mode = value;
    await load();
  }

  Future<void> selectDay(DateTime day) async {
    final selected = HistoryFormat.date(day);
    if (selected.year < 1 ||
        selected.isAfter(today) ||
        mode != HistoryMode.date) {
      return;
    }
    if (selectedDay != selected) _contentRevision++;
    selectedDay = selected;
    if (HistoryFormat.month(selected) != selectedMonth) {
      selectedMonth = HistoryFormat.month(selected);
      await load();
    } else {
      _notify();
    }
  }

  DateHistoryGroup? dayGroup(DateTime day) {
    for (final group in history?.dates ?? <DateHistoryGroup>[]) {
      if (group.date == day) return group;
    }
    return null;
  }

  void toggleMedication(int id) {
    if (!_expanded.remove(id)) _expanded.add(id);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    history = null;
    super.dispose();
  }
}

class AdherenceHistoryScope
    extends InheritedNotifier<AdherenceHistoryController> {
  const AdherenceHistoryScope(
      {super.key,
      required AdherenceHistoryController controller,
      required super.child})
      : super(notifier: controller);

  static AdherenceHistoryController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdherenceHistoryScope>()!
      .notifier!;
  static AdherenceHistoryController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdherenceHistoryScope>()!.notifier!;
}
