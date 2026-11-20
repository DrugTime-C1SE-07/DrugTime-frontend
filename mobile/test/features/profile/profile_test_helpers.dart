import 'dart:async';
import 'package:drugtime_mobile/features/profile/domain/entities/condition.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/profile_failure.dart';
import 'package:drugtime_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:drugtime_mobile/features/profile/domain/repositories/health_setup_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  HealthProfile value = HealthProfile(
      fullName: 'Nguyễn Mai',
      dateOfBirth: DateTime(1960, 3, 1),
      gender: 'nu',
      email: 'old@example.com',
      phone: '+84912345678');
  int reads = 0, writes = 0;
  ProfileDraft? lastDraft;
  Completer<HealthProfile>? pendingRead;
  Completer<void>? pendingWrite;
  ProfileFailure? fetchFailure, writeFailure;
  bool failFetchAfterWrite = false;
  int? lastLink;
  Map<String, String?>? lastPatch;
  List<int> offsets = [];
  @override
  Future<HealthProfile> fetch() async {
    reads++;
    if (fetchFailure case final f?) throw f;
    return pendingRead?.future ?? value;
  }

  @override
  Future<void> update(ProfileDraft draft) async {
    writes++;
    lastDraft = draft;
    if (pendingWrite != null) await pendingWrite!.future;
    if (writeFailure case final f?) throw f;
    value = HealthProfile(
        fullName: draft.fullName.trim(),
        dateOfBirth: draft.dateOfBirth,
        gender: draft.gender,
        email: draft.email ?? value.email,
        phone: value.phone,
        conditions: value.conditions);
    if (failFetchAfterWrite) {
      fetchFailure = const ProfileFailure(ProfileFailureKind.network);
    }
  }

  @override
  Future<ConditionPage> catalog({required int offset, int limit = 20}) async {
    offsets.add(offset);
    return ConditionPage(
        items: offset == 0
            ? [const ConditionItem(3, 'Tăng huyết áp')]
            : [const ConditionItem(4, 'Bệnh nền khác')],
        total: 2,
        offset: offset);
  }

  @override
  Future<ProfileCondition> addCondition(int conditionId) async {
    writes++;
    final c =
        ProfileCondition(id: 99, conditionId: conditionId, name: 'Bệnh nền');
    value = HealthProfile(
        fullName: value.fullName,
        dateOfBirth: value.dateOfBirth,
        gender: value.gender,
        email: value.email,
        phone: value.phone,
        conditions: [...value.conditions, c]);
    if (writeFailure case final f?) throw f;
    return c;
  }

  @override
  Future<ProfileCondition> updateCondition(
      int linkId, Map<String, String?> changes) async {
    writes++;
    lastLink = linkId;
    lastPatch = changes;
    final old = value.conditions.firstWhere((c) => c.id == linkId);
    final changed = ProfileCondition(
        id: old.id,
        conditionId: old.conditionId,
        name: old.name,
        subtype:
            changes.containsKey('subtype') ? changes['subtype'] : old.subtype,
        stage: changes.containsKey('stage') ? changes['stage'] : old.stage);
    value = HealthProfile(
        fullName: value.fullName,
        dateOfBirth: value.dateOfBirth,
        gender: value.gender,
        email: value.email,
        phone: value.phone,
        conditions: [
          for (final c in value.conditions) c.id == linkId ? changed : c
        ]);
    return changed;
  }

  @override
  Future<void> deleteCondition(int linkId) async {
    writes++;
    lastLink = linkId;
    value = HealthProfile(
        fullName: value.fullName,
        dateOfBirth: value.dateOfBirth,
        gender: value.gender,
        email: value.email,
        phone: value.phone,
        conditions: value.conditions.where((c) => c.id != linkId).toList());
    if (writeFailure case final f?) throw f;
  }
}

/// In-memory `/profile/health-setup` with both condition categories (N10).
class FakeHealthSetupRepository implements HealthSetupRepository {
  FakeHealthSetupRepository({HealthSetupSnapshot? initial})
      : current = initial ??
            const HealthSetupSnapshot(
                '1',
                HealthSetupStep(HealthSetupStatus.reported,
                    ids: ['penicillin']),
                HealthSetupStep(HealthSetupStatus.unreported),
                HealthSetupStep(HealthSetupStatus.unreported));
  HealthSetupSnapshot current;
  int saves = 0;
  bool failSave = false;
  final saved = <String>[];

  @override
  Future<HealthSetupSnapshot> read() async => current;

  @override
  Future<List<HealthSetupOption<String>>> allergens() async => const [
        HealthSetupOption('penicillin', 'Penicillin', category: 'drug'),
        HealthSetupOption('seafood', 'Hải sản', category: 'food'),
        HealthSetupOption('cephalosporin',
            'Cephalosporin (Cefalexin, Ceftriaxon, Cefuroxim…)',
            category: 'drug'),
      ];

  @override
  Future<List<HealthSetupOption<int>>> conditions() async => const [
        HealthSetupOption(3, 'Tăng huyết áp', category: 'chronic_disease'),
        HealthSetupOption(30, 'Đang mang thai',
            category: 'physiological_state'),
        HealthSetupOption(31, 'Đang cho con bú',
            category: 'physiological_state'),
      ];

  @override
  Future<HealthSetupSnapshot> save(String revision,
      {HealthSetupStep<String>? allergies,
      HealthSetupStep<int>? conditions,
      HealthSetupStep<int>? physiological}) async {
    if (failSave) throw const HealthSetupSaveException(needsReadback: false);
    saves++;
    if (allergies != null) saved.add('allergies');
    if (conditions != null) saved.add('conditions');
    if (physiological != null) saved.add('physiological');
    current = HealthSetupSnapshot(
        '${int.parse(current.revision) + 1}',
        allergies ?? current.allergies,
        conditions ?? current.conditions,
        physiological ?? current.physiological);
    return current;
  }
}
