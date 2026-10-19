import '../../domain/entities/condition.dart';
import '../../domain/entities/health_profile.dart';
import '../../domain/entities/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';

/// In-memory demo data for an explicitly enabled UI preview build only.
/// This repository is never an automatic fallback when the API fails.
class ProfilePreviewRepository implements ProfileRepository {
  HealthProfile _profile = HealthProfile(
    fullName: 'Nguyễn Minh Anh',
    dateOfBirth: DateTime(1985, 6, 15),
    gender: 'nu',
    email: 'minh.anh@example.com',
    conditions: const [
      ProfileCondition(
        id: 1001,
        conditionId: 1,
        name: 'Tăng huyết áp',
        subtype: 'Nguyên phát',
        stage: 'I',
      ),
    ],
  );
  int _nextLinkId = 1002;

  static const _catalog = <ConditionItem>[
    ConditionItem(1, 'Tăng huyết áp'),
    ConditionItem(2, 'Đái tháo đường'),
    ConditionItem(3, 'Hen phế quản'),
    ConditionItem(4, 'Rối loạn mỡ máu'),
    ConditionItem(5, 'Bệnh tim mạch'),
  ];

  @override
  Future<HealthProfile> fetch() async => _profile;

  @override
  Future<void> update(ProfileDraft draft) async {
    _profile = HealthProfile(
      fullName: draft.fullName.trim(),
      dateOfBirth: DateTime(
        draft.dateOfBirth.year,
        draft.dateOfBirth.month,
        draft.dateOfBirth.day,
      ),
      gender: draft.gender,
      email: draft.email ?? _profile.email,
      conditions: _profile.conditions,
    );
  }

  @override
  Future<ConditionPage> catalog({required int offset, int limit = 20}) async {
    if (offset < 0 || limit <= 0) {
      throw const ProfileFailure(ProfileFailureKind.validation);
    }
    final start = offset.clamp(0, _catalog.length);
    final end = (start + limit).clamp(0, _catalog.length);
    return ConditionPage(
      items: List.unmodifiable(_catalog.sublist(start, end)),
      total: _catalog.length,
      offset: offset,
    );
  }

  @override
  Future<ProfileCondition> addCondition(int conditionId) async {
    final item = _catalog.where((entry) => entry.id == conditionId);
    if (item.isEmpty) {
      throw const ProfileFailure(ProfileFailureKind.missing);
    }
    if (_profile.conditions.any((entry) => entry.conditionId == conditionId)) {
      throw const ProfileFailure(ProfileFailureKind.duplicate);
    }
    final linked = ProfileCondition(
      id: _nextLinkId++,
      conditionId: conditionId,
      name: item.first.name,
    );
    _replaceConditions([..._profile.conditions, linked]);
    return linked;
  }

  @override
  Future<ProfileCondition> updateCondition(
    int linkId,
    Map<String, String?> changes,
  ) async {
    final index = _profile.conditions.indexWhere((entry) => entry.id == linkId);
    if (index < 0) throw const ProfileFailure(ProfileFailureKind.missing);
    final old = _profile.conditions[index];
    final updated = ProfileCondition(
      id: old.id,
      conditionId: old.conditionId,
      name: old.name,
      subtype:
          changes.containsKey('subtype') ? changes['subtype'] : old.subtype,
      stage: changes.containsKey('stage') ? changes['stage'] : old.stage,
    );
    final conditions = [..._profile.conditions]..[index] = updated;
    _replaceConditions(conditions);
    return updated;
  }

  @override
  Future<void> deleteCondition(int linkId) async {
    final conditions = _profile.conditions.where((entry) => entry.id != linkId);
    if (conditions.length == _profile.conditions.length) {
      throw const ProfileFailure(ProfileFailureKind.missing);
    }
    _replaceConditions(conditions.toList());
  }

  void _replaceConditions(List<ProfileCondition> conditions) {
    _profile = HealthProfile(
      fullName: _profile.fullName,
      dateOfBirth: _profile.dateOfBirth,
      gender: _profile.gender,
      email: _profile.email,
      conditions: List.unmodifiable(conditions),
    );
  }
}
