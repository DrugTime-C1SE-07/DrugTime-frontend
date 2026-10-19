import 'package:flutter/widgets.dart';
import '../../../../core/utils/app_assets.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/health_profile.dart';
import '../../domain/entities/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._repository);
  final ProfileRepository? _repository;
  int _generation = 0;
  int _read = 0;
  bool _disposed = false;
  HealthProfile? profile;
  List<ConditionItem> catalogItems = const [];
  int _nextOffset = 0;
  bool hasMore = true;
  bool loading = false;
  bool saving = false;
  bool catalogLoading = false;
  ProfileFailure? error;
  ProfileFailure? catalogError;
  String? notice;
  String? avatar;
  int get generation => _generation;
  bool get denied => error?.removesAccess == true;
  bool _valid(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  ProfileRepository get _remote =>
      _repository ??
      (throw const ProfileFailure(ProfileFailureKind.unsupported));

  void clear() {
    _generation++;
    _read++;
    profile = null;
    catalogItems = const [];
    _nextOffset = 0;
    hasMore = true;
    loading = saving = catalogLoading = false;
    error = catalogError = null;
    avatar = notice = null;
    _notify();
  }

  void revoke() {
    clear();
    error = const ProfileFailure(ProfileFailureKind.consent);
    _notify();
  }

  void _fail(ProfileFailure failure) {
    if (failure.removesAccess) clear();
    error = failure;
  }

  void selectAvatar(String path) {
    if (!AppAssets.profileAvatars.contains(path)) {
      throw ArgumentError('Unknown avatar');
    }
    avatar = path;
    _notify();
  }

  Future<void> load() async {
    if (saving) return;
    final gen = _generation;
    final read = ++_read;
    loading = true;
    error = null;
    notice = null;
    _notify();
    try {
      final result = await _remote.fetch();
      if (_valid(gen) && read == _read) profile = result;
    } on ProfileFailure catch (failure) {
      if (_valid(gen) && read == _read) _fail(failure);
    } finally {
      if (_valid(gen) && read == _read) loading = false;
      _notify();
    }
  }

  Future<void> loadCatalog({bool reset = false}) async {
    if (catalogLoading || denied || saving) return;
    if (!reset && !hasMore) return;
    final gen = _generation;
    if (reset) {
      catalogItems = const [];
      _nextOffset = 0;
      hasMore = true;
    }
    catalogLoading = true;
    catalogError = null;
    _notify();
    try {
      final page = await _remote.catalog(offset: _nextOffset);
      if (!_valid(gen)) return;
      final merged = {
        for (final item in catalogItems) item.id: item,
        for (final item in page.items) item.id: item
      };
      catalogItems = List.unmodifiable(merged.values);
      _nextOffset = page.offset + page.items.length;
      hasMore = page.items.isNotEmpty && _nextOffset < page.total;
    } on ProfileFailure catch (failure) {
      if (_valid(gen)) {
        if (failure.removesAccess) {
          _fail(failure);
        } else {
          catalogError = failure;
        }
      }
    } finally {
      if (_valid(gen)) catalogLoading = false;
      _notify();
    }
  }

  /// Serialize writes. Every completion checks the session generation, including
  /// refetch/reconciliation, so an old account can never repopulate state.
  Future<bool> _write(Future<void> Function(ProfileRepository repo) action,
      {bool Function(HealthProfile fresh)? reconciled}) async {
    if (saving || loading || denied || profile == null) return false;
    final gen = _generation;
    _read++;
    saving = true;
    error = null;
    notice = null;
    _notify();
    var acknowledged = false;
    try {
      await action(_remote);
      if (!_valid(gen)) return false;
      acknowledged = true;
      final fresh = await _remote.fetch();
      if (!_valid(gen)) return false;
      profile = fresh;
      notice = 'Đã lưu thay đổi';
      return true;
    } on ProfileFailure catch (failure) {
      if (!_valid(gen)) return false;
      if (failure.removesAccess) {
        _fail(failure);
        return false;
      }
      if (acknowledged) {
        // The mutation succeeded; do not suggest sending the same write again.
        notice = 'Đã lưu. Chưa tải lại được hồ sơ, vui lòng tải lại.';
        error = failure;
        return true;
      }
      if (reconciled != null &&
          {
            ProfileFailureKind.network,
            ProfileFailureKind.unavailable,
            ProfileFailureKind.duplicate,
            ProfileFailureKind.missing
          }.contains(failure.kind)) {
        try {
          final fresh = await _remote.fetch();
          if (!_valid(gen)) return false;
          profile = fresh;
          if (reconciled(fresh) &&
              failure.kind != ProfileFailureKind.duplicate) {
            notice = 'Đã cập nhật hồ sơ';
            return true;
          }
        } on ProfileFailure catch (checkFailure) {
          if (!_valid(gen)) return false;
          if (checkFailure.removesAccess) {
            _fail(checkFailure);
            return false;
          }
          // Keep the original mutation error; no automatic mutation retry.
        }
      }
      error = failure;
      return false;
    } finally {
      if (_valid(gen)) saving = false;
      _notify();
    }
  }

  Future<bool> update(ProfileDraft draft) =>
      _write((repo) => repo.update(draft));
  Future<bool> addCondition(int id) => _write((repo) async {
        await repo.addCondition(id);
      },
          reconciled: (fresh) =>
              fresh.conditions.any((c) => c.conditionId == id));
  Future<bool> updateCondition(int id, Map<String, String?> changes) {
    if (changes.isEmpty) return Future.value(true);
    return _write((repo) async {
      await repo.updateCondition(id, changes);
    },
        reconciled: (fresh) => fresh.conditions.any((c) =>
            c.id == id &&
            (!changes.containsKey('subtype') ||
                c.subtype == changes['subtype']) &&
            (!changes.containsKey('stage') || c.stage == changes['stage'])));
  }

  Future<bool> deleteCondition(int id) =>
      _write((repo) => repo.deleteCondition(id),
          reconciled: (fresh) => !fresh.conditions.any((c) => c.id == id));
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class ProfileScope extends InheritedNotifier<ProfileController> {
  const ProfileScope(
      {super.key, required ProfileController controller, required super.child})
      : super(notifier: controller);
  static ProfileController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()!.notifier!;
  static ProfileController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProfileScope>()!.notifier!;
}
