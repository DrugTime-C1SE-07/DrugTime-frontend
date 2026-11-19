import 'package:flutter/foundation.dart';

import '../../domain/entities/health_setup.dart';
import '../../domain/repositories/health_setup_repository.dart';

/// Tên dị ứng tự nhập được gửi nguyên sang gợi ý món ăn, mỗi mục tối đa 40 ký tự.
const maxAllergyNameLength = 40;
const maxConditionNameLength = 120;

class HealthSetupDraft<T> {
  HealthSetupDraft(HealthSetupStep<T> step,
      {this.maxNameLength = maxConditionNameLength})
      : ids = Set<T>.of(step.ids),
        names = step.names.toList(),
        noneKnown = step.status == HealthSetupStatus.noneKnown;

  final int maxNameLength;
  final Set<T> ids;
  final List<String> names;
  bool noneKnown;
  bool get canContinue => noneKnown || ids.isNotEmpty || names.isNotEmpty;

  void toggle(T id) {
    noneKnown = false;
    if (!ids.add(id)) ids.remove(id);
  }

  void toggleNone() {
    noneKnown = !noneKnown;
    if (noneKnown) {
      ids.clear();
      names.clear();
    }
  }

  bool addCustom(String input) {
    final name = input.trim();
    if (name.isEmpty ||
        names.length >= 30 ||
        name.runes.length > maxNameLength ||
        name.contains('\u0000') ||
        names.any((value) => value.toLowerCase() == name.toLowerCase())) {
      return false;
    }
    names.add(name);
    noneKnown = false;
    return true;
  }

  HealthSetupStep<T> get value => HealthSetupStep(
        noneKnown
            ? HealthSetupStatus.noneKnown
            : canContinue
                ? HealthSetupStatus.reported
                : HealthSetupStatus.unreported,
        ids: ids.toList(),
        names: names.toList(),
      );
}

enum HealthSetupSaveResult { saved, skipped, failed }

class HealthSetupController extends ChangeNotifier {
  HealthSetupController(this._repository);

  final HealthSetupRepository? _repository;
  HealthSetupSnapshot? snapshot;
  HealthSetupSnapshot? saved;
  late HealthSetupDraft<String> allergyDraft;
  late HealthSetupDraft<int> conditionDraft;
  List<HealthSetupOption<String>> allergenOptions = const [];
  List<HealthSetupOption<int>> conditionOptions = const [];
  bool loading = false;
  bool loadFailed = false;
  bool saving = false;
  bool saveFailed = false;
  bool conflict = false;
  bool _disposed = false;
  bool _includeAllergies = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    loadFailed = false;
    notifyListeners();
    try {
      final repo = _repository;
      if (repo == null) throw StateError('Health setup unavailable');
      final (profile, allergens, conditions) =
          await (repo.read(), repo.allergens(), repo.conditions()).wait;
      if (_disposed) return;
      snapshot = profile;
      allergenOptions = allergens;
      conditionOptions = conditions;
      allergyDraft = HealthSetupDraft(profile.allergies,
          maxNameLength: maxAllergyNameLength);
      conditionDraft = HealthSetupDraft(profile.conditions);
    } catch (_) {
      if (!_disposed) loadFailed = true;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void includeAllergies(bool include) => _includeAllergies = include;

  Future<HealthSetupSaveResult> finish(
      {required bool includeConditions}) async {
    final profile = snapshot;
    final repo = _repository;
    if (profile == null || repo == null || saving) {
      return HealthSetupSaveResult.failed;
    }
    final allergies = _includeAllergies ? allergyDraft.value : null;
    final conditions = includeConditions ? conditionDraft.value : null;
    if (allergies == null && conditions == null) {
      return HealthSetupSaveResult.skipped;
    }
    saving = true;
    saveFailed = false;
    conflict = false;
    notifyListeners();
    try {
      saved = await repo.save(profile.revision,
          allergies: allergies, conditions: conditions);
      return HealthSetupSaveResult.saved;
    } on HealthSetupSaveException catch (error) {
      if (error.needsReadback && !_disposed) {
        try {
          final fresh = await repo.read();
          if (_disposed) return HealthSetupSaveResult.failed;
          final same =
              (allergies == null || allergies.matches(fresh.allergies)) &&
                  (conditions == null || conditions.matches(fresh.conditions));
          if (same) {
            saved = fresh;
            return HealthSetupSaveResult.saved;
          }
          conflict = fresh.revision != profile.revision;
          snapshot = fresh;
        } catch (_) {
          // A failed readback leaves the prior revision in place for retry.
        }
      }
      saveFailed = true;
      return HealthSetupSaveResult.failed;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
