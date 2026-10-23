import 'package:flutter/foundation.dart';
import '../../domain/entities/family_alert.dart';
import '../../domain/repositories/family_alert_repository.dart';

class FamilyAlertController extends ChangeNotifier {
  FamilyAlertController(this.repository);
  final FamilyAlertRepository repository;
  List<FamilyAlert> items = const [];
  FamilyAlert? detail;
  int? unreadCount;
  int total = 0;
  bool loading = false, saving = false;
  FamilyAlertFailure? error;
  // Epoch vô hiệu cả phiên; hai bộ đếm riêng loại response cũ của list và detail.
  int _epoch = 0, _load = 0, _detailLoad = 0;
  String? _session;
  bool _ready = false;
  int? openId;
  bool _disposed = false;

  void setSession(String? session, {required bool ready}) {
    if (_session == session && _ready == ready) return;
    _session = session;
    _ready = ready;
    openId = null;
    clear();
  }

  bool get ready => _session != null && _ready;
  // Tăng generation trước khi xóa RAM để request cũ không điền lại dữ liệu.
  void clear() {
    _epoch++;
    _load++;
    _detailLoad++;
    items = const [];
    detail = null;
    unreadCount = null;
    total = 0;
    loading = false;
    saving = false;
    error = null;
    if (!_disposed) notifyListeners();
  }

  void _failure(FamilyAlertFailure failure) {
    if (failure.clearsHealth) clear();
    error = failure;
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool more = false}) async {
    if (!ready) return;
    final epoch = _epoch, run = ++_load;
    final offset = more ? items.length : 0;
    loading = true;
    error = null;
    unreadCount = null;
    if (!more) items = const [];
    notifyListeners();
    try {
      final page = await repository.list(offset: offset);
      if (_disposed || epoch != _epoch || run != _load) return;
      items = List.unmodifiable([if (more) ...items, ...page.items]);
      total = page.total;
      unreadCount = page.unreadCount;
    } on FamilyAlertFailure catch (e) {
      if (_disposed || epoch != _epoch || run != _load) return;
      _failure(e);
    } finally {
      if (!_disposed && epoch == _epoch && run == _load) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> open(int id) async {
    openId = id;
    if (!ready) return;
    final epoch = _epoch, run = ++_detailLoad;
    detail = null;
    error = null;
    loading = true;
    saving = false;
    notifyListeners();
    try {
      final item = await repository.detail(id);
      if (_disposed || epoch != _epoch || run != _detailLoad) return;
      detail = item;
    } on FamilyAlertFailure catch (e) {
      if (_disposed || epoch != _epoch || run != _detailLoad) return;
      _failure(e);
    } finally {
      if (!_disposed && epoch == _epoch && run == _detailLoad) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markRead() async {
    final current = detail;
    if (!ready || current == null || saving) return;
    // Gắn PATCH với detail đang mở để response A không sửa màn B khi chuyển nhanh.
    final epoch = _epoch, run = _detailLoad;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final item = await repository.markRead(current.id);
      if (_disposed || epoch != _epoch || run != _detailLoad) return;
      if (item.patientId != current.patientId) {
        throw const FamilyAlertFailure('invalid_response');
      }
      detail = item;
      items = List.unmodifiable(items.map((r) => r.id == item.id ? item : r));
      // Lấy lại count từ server sau PATCH, không tự trừ badge theo state cục bộ.
      await load();
    } on FamilyAlertFailure catch (e) {
      if (_disposed || epoch != _epoch || run != _detailLoad) return;
      _failure(e);
    } finally {
      if (!_disposed && epoch == _epoch && run == _detailLoad) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
