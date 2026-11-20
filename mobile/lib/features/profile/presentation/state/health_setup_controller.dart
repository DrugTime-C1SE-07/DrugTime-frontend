import 'package:flutter/foundation.dart';

import '../../domain/entities/condition.dart';
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

/// The three health-setup steps, in flow order. The physiological step is skipped for men.
enum HealthSetupStepKind { allergy, condition, physiological }

class HealthSetupController extends ChangeNotifier {
  HealthSetupController(this._repository, {this.onSaved});

  /// Called with each saved snapshot (shared status for Home and the profile screens).
  final void Function(HealthSetupSnapshot saved)? onSaved;

  final HealthSetupRepository? _repository;
  HealthSetupSnapshot? snapshot;
  HealthSetupSnapshot? saved;
  late HealthSetupDraft<String> allergyDraft;
  late HealthSetupDraft<int> conditionDraft;
  late HealthSetupDraft<int> physiologicalDraft;
  List<HealthSetupOption<String>> allergenOptions = const [];

  /// Whole condition catalog (both categories); use [chronicOptions] or
  /// [physiologicalOptions] for a step.
  List<HealthSetupOption<int>> conditionOptions = const [];
  List<HealthSetupOption<int>> get chronicOptions => conditionOptions
      .where((o) => o.category != ConditionCategory.physiologicalState.api)
      .toList(growable: false);
  List<HealthSetupOption<int>> get physiologicalOptions => conditionOptions
      .where((o) => o.category == ConditionCategory.physiologicalState.api)
      .toList(growable: false);
  bool loading = false;
  bool loadFailed = false;
  bool saving = false;
  bool saveFailed = false;
  bool conflict = false;
  bool _disposed = false;
  bool _includeAllergies = false;
  bool _includeConditions = false;

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
      physiologicalDraft = HealthSetupDraft(profile.physiological);
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
  void includeConditions(bool include) => _includeConditions = include;

  HealthSetupDraft<Object> draftOf(HealthSetupStepKind kind) => switch (kind) {
        HealthSetupStepKind.allergy => allergyDraft,
        HealthSetupStepKind.condition => conditionDraft,
        HealthSetupStepKind.physiological => physiologicalDraft,
      };

  /// Saves only [kind] (health profile screen, auto-save). An unanswered draft is skipped.
  Future<HealthSetupSaveResult> saveStep(HealthSetupStepKind kind) {
    final value = switch (kind) {
      HealthSetupStepKind.allergy => allergyDraft.value,
      HealthSetupStepKind.condition => conditionDraft.value,
      HealthSetupStepKind.physiological => physiologicalDraft.value,
    };
    if (value.status == HealthSetupStatus.unreported) {
      return Future.value(HealthSetupSaveResult.skipped);
    }
    return _save(
      allergies: kind == HealthSetupStepKind.allergy
          ? value as HealthSetupStep<String>
          : null,
      conditions: kind == HealthSetupStepKind.condition
          ? value as HealthSetupStep<int>
          : null,
      physiological: kind == HealthSetupStepKind.physiological
          ? value as HealthSetupStep<int>
          : null,
    );
  }

  /// End of the setup flow: saves every step the user answered (skipped ones are omitted).
  Future<HealthSetupSaveResult> finish(
      {required bool includeConditions, bool includePhysiological = false}) {
    final allergies = _includeAllergies ? allergyDraft.value : null;
    final conditions =
        includeConditions || _includeConditions ? conditionDraft.value : null;
    final physiological =
        includePhysiological ? physiologicalDraft.value : null;
    return _save(
        allergies: allergies,
        conditions: conditions,
        physiological: physiological);
  }

  Future<HealthSetupSaveResult> _save({
    HealthSetupStep<String>? allergies,
    HealthSetupStep<int>? conditions,
    HealthSetupStep<int>? physiological,
  }) async {
    final profile = snapshot;
    final repo = _repository;
    if (profile == null || repo == null || saving) {
      return HealthSetupSaveResult.failed;
    }
    if (allergies == null && conditions == null && physiological == null) {
      return HealthSetupSaveResult.skipped;
    }
    saving = true;
    saveFailed = false;
    conflict = false;
    notifyListeners();
    try {
      saved = await repo.save(profile.revision,
          allergies: allergies,
          conditions: conditions,
          physiological: physiological);
      snapshot = saved;
      onSaved?.call(saved!);
      return HealthSetupSaveResult.saved;
    } on HealthSetupSaveException catch (error) {
      if (error.needsReadback && !_disposed) {
        try {
          final fresh = await repo.read();
          if (_disposed) return HealthSetupSaveResult.failed;
          final same = (allergies == null ||
                  allergies.matches(fresh.allergies)) &&
              (conditions == null || conditions.matches(fresh.conditions)) &&
              (physiological == null ||
                  physiological.matches(fresh.physiological));
          if (same) {
            saved = fresh;
            snapshot = fresh;
            onSaved?.call(fresh);
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
