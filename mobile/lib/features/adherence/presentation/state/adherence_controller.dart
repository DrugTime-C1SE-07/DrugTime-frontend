import 'package:flutter/foundation.dart';

import '../../domain/entities/adherence_failure.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/repositories/adherence_repository.dart';

/// State belongs to one screen lifetime. A new request never exposes old health data.
class AdherenceController extends ChangeNotifier {
  AdherenceController(
    this._repository, {
    required this.patientId,
    DateTime Function()? now,
    bool available = true,
  })  : _now = now ?? DateTime.now,
        _available = available {
    selectedDate = today;
  }

  final AdherenceRepository _repository;
  final DateTime Function() _now;
  int _generation = 0;
  bool _disposed = false;
  bool _available;

  bool get available => _available;

  void setAvailable(bool value) {
    if (_disposed || _available == value) return;
    _available = value;
    if (!value) clear();
  }

  String patientId;
  late DateTime selectedDate;
  AdherenceHistory? history;
  AdherenceFailure? failure;
  bool loading = false;

  DateTime get today {
    final current = vietnamWallTime(_now());
    return DateTime.utc(current.year, current.month, current.day);
  }

  DateTime get earliestDate => today.subtract(const Duration(days: 89));

  DateTime get rangeFrom {
    final monthStart = DateTime.utc(selectedDate.year, selectedDate.month);
    return monthStart.isBefore(earliestDate) ? earliestDate : monthStart;
  }

  DateTime get rangeTo {
    final monthEnd = DateTime.utc(selectedDate.year, selectedDate.month + 1, 0);
    return monthEnd.isAfter(today) ? today : monthEnd;
  }

  AdherenceDateGroup? get selectedGroup => history?.groupFor(selectedDate);

  bool get denied => failure?.kind == AdherenceFailureKind.denied;

  bool get canRetry => {
        AdherenceFailureKind.network,
        AdherenceFailureKind.unavailable,
      }.contains(failure?.kind);

  Future<void> load() async {
    if (_disposed || !_available) return;
    final generation = ++_generation;
    final requestedPatient = patientId;
    final from = rangeFrom;
    final to = rangeTo;
    history = null;
    failure = null;
    loading = true;
    notifyListeners();
    try {
      final result = await _repository.fetch(
        patientId: requestedPatient,
        from: from,
        to: to,
      );
      if (!_current(generation, requestedPatient)) return;
      if (result.patientId != requestedPatient) {
        failure = const AdherenceFailure(AdherenceFailureKind.invalidResponse);
      } else {
        history = result;
      }
    } on AdherenceFailure catch (error) {
      if (_current(generation, requestedPatient)) failure = error;
    } finally {
      if (_current(generation, requestedPatient)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> changePatient(String value) async {
    if (_disposed || value == patientId) return;
    patientId = value;
    selectedDate = today;
    await load();
  }

  Future<bool> selectDate(DateTime value) async {
    if (_disposed) return false;
    final day = DateTime.utc(value.year, value.month, value.day);
    if (day.isBefore(earliestDate) || day.isAfter(today)) return false;
    if (sameCalendarDate(selectedDate, day)) return true;
    selectedDate = day;
    await load();
    return true;
  }

  Future<void> refresh() => load();

  void clear() {
    _generation++;
    history = null;
    failure = null;
    loading = false;
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation, String patient) =>
      !_disposed && generation == _generation && patient == patientId;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    history = null;
    super.dispose();
  }
}
