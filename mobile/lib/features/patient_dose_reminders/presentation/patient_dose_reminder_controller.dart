import 'package:flutter/foundation.dart';
import '../../../core/storage/local_db/client_uuid.dart';

import '../../../core/api/api_exception.dart';
import '../data/patient_dose_reminder_repository.dart';

class PatientDoseReminderController extends ChangeNotifier {
  PatientDoseReminderController(this.repository,
      {this.onDenied, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final PatientDoseReminderRepository repository;
  final void Function(String)? onDenied;
  final DateTime Function() clock;
  int _revision = 0;
  String? _patientId;
  bool _disposed = false;
  final _commands = <OccurrenceKey, String>{};
  final _receipts = <OccurrenceKey, ReminderReceipt?>{};
  final _busy = <OccurrenceKey>{};
  final _retryAt = <OccurrenceKey, DateTime>{};
  final _messages = <OccurrenceKey, String>{};

  void select(String? patientId) {
    _revision++;
    _patientId = patientId;
    _commands.clear();
    _receipts.clear();
    _busy.clear();
    _messages.clear();
    _retryAt.clear();
    if (!_disposed) notifyListeners();
  }

  bool busy(OccurrenceKey key) => _busy.contains(key);
  ReminderReceipt? receipt(OccurrenceKey key) => _receipts[key];
  String? message(OccurrenceKey key) => _messages[key];
  Duration wait(OccurrenceKey key) {
    final at = _retryAt[key] ?? _receipts[key]?.nextAllowedAt;
    if (at == null) return Duration.zero;
    final value = at.difference(clock().toUtc());
    return value.isNegative ? Duration.zero : value;
  }

  Future<void> loadStatus(OccurrenceKey key) => _run(key, sending: false);
  Future<void> send(OccurrenceKey key) => _run(key, sending: true);

  Future<void> _run(OccurrenceKey key, {required bool sending}) async {
    final patient = _patientId, revision = _revision;
    if (patient == null || _disposed || !_busy.add(key)) return;
    notifyListeners();
    bool current() =>
        !_disposed && revision == _revision && patient == _patientId;
    try {
      if (!sending || !_receipts.containsKey(key)) {
        final status = await repository.status(patient, key);
        if (!current()) return;
        _receipts[key] = status;
      }
      if (sending && wait(key) == Duration.zero) {
        final uuid = _commands.putIfAbsent(key, createClientUuid);
        final receipt = await repository.send(patient, key, uuid);
        if (!current()) return;
        _receipts[key] = receipt;
        _commands.remove(key);
        _messages[key] = 'Đã gửi yêu cầu nhắc';
      }
    } on ApiException catch (error) {
      if (!current()) return;
      if (error.statusCode == 403) {
        onDenied?.call(patient);
        return;
      }
      if (error.statusCode == 429) {
        _retryAt[key] = clock()
            .toUtc()
            .add(error.retryAfter ?? const Duration(seconds: 600));
        _commands.remove(key);
      }
      if (error.statusCode == 409 || error.statusCode == 422) {
        _commands.remove(key);
        _receipts.remove(key);
      }
      _messages[key] = switch (error.statusCode) {
        409 => 'Liều đã thay đổi. Hãy tải lại dữ liệu.',
        422 => 'Lần uống này hiện không thể gửi nhắc.',
        429 => 'Chưa đến thời gian nhắc lại.',
        _ => 'Chưa xác nhận được yêu cầu. Bạn có thể thử lại.',
      };
    } on FormatException {
      if (current()) {
        _messages[key] = 'Dữ liệu lời nhắc không hợp lệ. Hãy thử lại.';
      }
    } on TypeError {
      if (current()) {
        _messages[key] = 'Dữ liệu lời nhắc không hợp lệ. Hãy thử lại.';
      }
    } finally {
      if (current()) {
        _busy.remove(key);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
