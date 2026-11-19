import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../family_link/presentation/state/linked_patients_controller.dart';
import '../../interaction_check/domain/entities/interaction_check_result.dart';
import '../../patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import '../../patient_dose_reminders/presentation/patient_dose_reminder_controller.dart';
import '../data/patient_monitor_repository.dart';
import '../domain/monitor_models.dart';

class PatientMonitorController extends ChangeNotifier {
  PatientMonitorController(this.repository, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now {
    reminders = PatientDoseReminderController(
        PatientDoseReminderRepository(repository.api),
        onDenied: revoke,
        clock: this.clock);
  }
  final PatientMonitorRepository repository;
  final DateTime Function() clock;
  final linked = LinkedPatientsController();
  late final PatientDoseReminderController reminders;
  int _sessionRevision = 0,
      _selectionRevision = 0,
      _hubRevision = 0,
      _rangeRevision = 0;
  String? _session, patientId;
  bool ready = false, loadingHub = false, loading = false, denied = false;
  bool _hubActive = false, _disposed = false;
  String? hubError, error, rangeError, interactionError;
  MonitorSnapshot? snapshot;
  MonitorHistory? range;
  InteractionCheckResult? interactions;
  Map<String, dynamic>? food;
  final summaries = <String, MonitorSnapshot>{};
  final summaryErrors = <String>{};
  int get sessionRevision => _sessionRevision;

  String get patientName {
    for (final patient in linked.patients) {
      if (patient.id == patientId) {
        return patient.name.isEmpty ? 'Người bệnh' : patient.name;
      }
    }
    return 'Người bệnh';
  }

  void setSession(String? session, {required bool available}) {
    if (_disposed) return;
    if (_session == session && ready == available) return;
    _session = session;
    ready = available;
    _sessionRevision++;
    _selectionRevision++;
    _hubRevision++;
    _rangeRevision++;
    patientId = null;
    snapshot = null;
    range = null;
    interactions = null;
    food = null;
    denied = false;
    error = null;
    rangeError = null;
    interactionError = null;
    summaries.clear();
    summaryErrors.clear();
    linked.clear();
    reminders.select(null);
    loading = false;
    loadingHub = false;
    hubError =
        available ? null : 'Cần kết nối và phiên đăng nhập để xem thông tin.';
    notifyListeners();
    if (available && _hubActive) unawaited(loadHub());
  }

  void setHubActive(bool active) {
    _hubActive = active;
    if (!active) {
      _hubRevision++;
      loadingHub = false;
    }
    if (active && ready) unawaited(loadHub());
  }

  Future<void> loadHub() async {
    if (!ready || _disposed) return;
    final revision = ++_hubRevision, session = _sessionRevision;
    loadingHub = true;
    hubError = null;
    notifyListeners();
    bool current() =>
        !_disposed &&
        ready &&
        session == _sessionRevision &&
        revision == _hubRevision;
    try {
      final patients = await repository.patients();
      if (!current()) return;
      await linked.syncPatients(patients);
      if (!current()) return;
      if (patientId != null && !linked.hasPatient(patientId!)) {
        revoke(patientId!);
      }
      summaries.removeWhere((id, _) => !linked.hasPatient(id));
      loadingHub = false;
      notifyListeners();
      for (var offset = 0; offset < patients.length; offset += 3) {
        if (!current() || !_hubActive) return;
        await Future.wait(patients.skip(offset).take(3).map((patient) async {
          try {
            final data = await repository.today(patient.id,
                now: clock(), includeMedications: false);
            if (!current() || !linked.hasPatient(patient.id)) return;
            summaries[patient.id] = data;
            summaryErrors.remove(patient.id);
          } on ApiException catch (e) {
            if (!current()) return;
            if (e.statusCode == 403) {
              revoke(patient.id);
            } else {
              summaryErrors.add(patient.id);
            }
          } on FormatException {
            if (current()) summaryErrors.add(patient.id);
          } on TypeError {
            if (current()) summaryErrors.add(patient.id);
          }
          if (current()) notifyListeners();
        }));
      }
    } on ApiException {
      if (current()) hubError = 'Chưa tải được danh sách. Hãy thử lại.';
    } on FormatException {
      if (current()) hubError = 'Dữ liệu danh sách không hợp lệ.';
    } on TypeError {
      if (current()) hubError = 'Dữ liệu danh sách không hợp lệ.';
    } finally {
      if (current()) {
        loadingHub = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(String id) async {
    if (!ready || !linked.hasPatient(id) || _disposed) return;
    patientId = id;
    denied = false;
    reminders.select(id);
    await refresh();
  }

  bool _current(int session, int selection, String id) =>
      !_disposed &&
      ready &&
      session == _sessionRevision &&
      selection == _selectionRevision &&
      patientId == id &&
      !denied;

  Future<void> refresh() async {
    final id = patientId;
    if (id == null || !ready || _disposed || denied) return;
    final selection = ++_selectionRevision, session = _sessionRevision;
    snapshot = null;
    range = null;
    interactions = null;
    food = null;
    error = null;
    rangeError = null;
    interactionError = null;
    loading = true;
    notifyListeners();
    try {
      final data = await repository.today(id, now: clock());
      if (_current(session, selection, id)) snapshot = data;
    } on ApiException catch (e) {
      if (_current(session, selection, id)) {
        if (e.statusCode == 403) {
          revoke(id);
        } else {
          error = 'Chưa tải đủ dữ liệu. Hãy thử lại.';
        }
      }
    } on FormatException {
      if (_current(session, selection, id)) error = 'Dữ liệu không hợp lệ.';
    } on TypeError {
      if (_current(session, selection, id)) error = 'Dữ liệu không hợp lệ.';
    } finally {
      if (_current(session, selection, id)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadHistory(DateTime from, DateTime to) async {
    final id = patientId;
    if (id == null || !ready || denied) return;
    final session = _sessionRevision,
        selection = _selectionRevision,
        revision = ++_rangeRevision;
    range = null;
    rangeError = null;
    notifyListeners();
    final today = monitorDay(clock());
    final floor = today.subtract(const Duration(days: 89));
    from = from.isBefore(floor) ? floor : from;
    to = to.isAfter(today) ? today : to;
    try {
      final report = await repository.history(id, from, to);
      if (_current(session, selection, id) && revision == _rangeRevision) {
        range = report;
      }
    } on ApiException catch (e) {
      if (_current(session, selection, id) && revision == _rangeRevision) {
        if (e.statusCode == 403) {
          revoke(id);
        } else {
          rangeError = 'Chưa tải được lịch sử.';
        }
      }
    } on FormatException {
      if (_current(session, selection, id) && revision == _rangeRevision) {
        rangeError = 'Dữ liệu không hợp lệ.';
      }
    } on TypeError {
      if (_current(session, selection, id) && revision == _rangeRevision) {
        rangeError = 'Dữ liệu không hợp lệ.';
      }
    } finally {
      if (_current(session, selection, id)) notifyListeners();
    }
  }

  Future<void> loadInteractions() async {
    final id = patientId;
    if (id == null || !ready || denied) return;
    final session = _sessionRevision, selection = _selectionRevision;
    interactions = null;
    food = null;
    interactionError = null;
    notifyListeners();
    try {
      final drugResult = await repository.interactions(id);
      if (!_current(session, selection, id)) return;
      final foodResult = await repository.foodInteractions(id);
      if (_current(session, selection, id)) {
        interactions = drugResult;
        food = foodResult;
      }
    } on ApiException catch (e) {
      if (_current(session, selection, id)) {
        if (e.statusCode == 403) {
          revoke(id);
        } else {
          interactionError = 'Chưa tải đủ kết quả tương tác.';
        }
      }
    } on FormatException {
      if (_current(session, selection, id)) {
        interactionError = 'Kết quả không hợp lệ.';
      }
    } on TypeError {
      if (_current(session, selection, id)) {
        interactionError = 'Kết quả không hợp lệ.';
      }
    } finally {
      if (_current(session, selection, id)) notifyListeners();
    }
  }

  void revoke(String id) {
    summaries.remove(id);
    summaryErrors.remove(id);
    if (patientId == id) {
      _selectionRevision++;
      _rangeRevision++;
      snapshot = null;
      range = null;
      interactions = null;
      food = null;
      denied = true;
      loading = false;
      reminders.select(null);
    }
    unawaited(linked.handleRevocation(id));
    if (!_disposed) notifyListeners();
  }

  void leave() {
    _selectionRevision++;
    _rangeRevision++;
    patientId = null;
    snapshot = null;
    range = null;
    interactions = null;
    food = null;
    denied = false;
    reminders.select(null);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionRevision++;
    linked.dispose();
    reminders.dispose();
    super.dispose();
  }
}
