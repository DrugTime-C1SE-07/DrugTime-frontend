import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/storage/local_db/local_medication_store.dart';
import '../../../family/presentation/state/family_alert_controller.dart';

/// Đại diện bệnh nhân đang liên kết với người thân (vai Family Member).
class LinkedPatient {
  const LinkedPatient({required this.id, this.name = ''});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkedPatient &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LinkedPatient(id: $id, name: $name)';
}

/// Điều phối danh sách bệnh nhân đang liên kết của Family Member,
/// xử lý thu hồi quyền truy cập (khi nhận HTTP 403) và đồng bộ danh sách mới (QD-29, AC6–AC9).
class LinkedPatientsController extends ChangeNotifier {
  LinkedPatientsController({
    LocalMedicationStore? localStore,
    FamilyAlertController? alertController,
    List<LinkedPatient> initialPatients = const [],
  })  : _localStore = localStore,
        _alertController = alertController,
        _patients = List.of(initialPatients);

  final LocalMedicationStore? _localStore;
  final FamilyAlertController? _alertController;
  final Set<String> _processingRevocations = {};
  List<LinkedPatient> _patients;
  bool _disposed = false;

  /// Danh sách bệnh nhân đang liên kết hợp lệ.
  List<LinkedPatient> get patients => List.unmodifiable(_patients);

  /// Danh sách ID bệnh nhân đang liên kết.
  List<String> get patientIds => _patients.map((p) => p.id).toList();

  /// Kiểm tra xem [patientId] có trong danh sách hợp lệ hay không.
  bool hasPatient(String patientId) => _patients.any((p) => p.id == patientId);

  /// Xử lý khi nhận HTTP 403 Forbidden hoặc thu hồi liên kết đối với [patientId] (AC6, AC9).
  ///
  /// 1. Xóa ngay patient khỏi danh sách state cục bộ để UI cập nhật lập tức.
  /// 2. Xóa sạch cache lịch uống trong SQLite cục bộ (`clearPatientData`).
  /// 3. Lọc bỏ các cảnh báo của patient trong `FamilyAlertController`.
  /// 4. An toàn khi gọi nhiều lần (idempotent) hoặc chạy đua nhiều request đồng thời.
  Future<void> handleRevocation(String patientId) async {
    if (_disposed) return;

    final hasMatch = _patients.any((p) => p.id == patientId);
    if (hasMatch) {
      _patients = _patients.where((p) => p.id != patientId).toList();
      _notify();
    }

    if (!_processingRevocations.add(patientId)) {
      return;
    }

    try {
      if (_localStore != null) {
        await _localStore.clearPatientData(patientId);
      }
      _alertController?.removePatient(patientId);
    } finally {
      _processingRevocations.remove(patientId);
    }
  }

  /// Hook thuận tiện truyền vào `AdherenceController.onPatientRevoked`.
  Future<void> onPatientRevoked(String patientId) => handleRevocation(patientId);

  /// Đồng bộ danh sách bệnh nhân mới từ server (AC7, AC8).
  ///
  /// So sánh với danh sách hiện tại; các bệnh nhân không còn trong danh sách mới
  /// sẽ được gỡ bỏ và dọn dẹp cache tương ứng mà không làm ảnh hưởng bệnh nhân còn lại.
  Future<void> syncPatients(List<LinkedPatient> newPatients) async {
    if (_disposed) return;

    final newIds = newPatients.map((p) => p.id).toSet();
    final removed = _patients.where((p) => !newIds.contains(p.id)).toList();

    _patients = List.of(newPatients);
    _notify();

    for (final patient in removed) {
      await handleRevocation(patient.id);
    }
  }

  /// Đồng bộ danh sách bằng ID.
  Future<void> syncPatientIds(List<String> newPatientIds) async {
    final nameMap = {for (final p in _patients) p.id: p.name};
    final newList = newPatientIds
        .map((id) => LinkedPatient(id: id, name: nameMap[id] ?? ''))
        .toList();
    await syncPatients(newList);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
