import 'package:unorm_dart/unorm_dart.dart' as unorm;

enum HealthSetupStatus { unreported, noneKnown, reported }

class HealthSetupStep<T> {
  const HealthSetupStep(this.status,
      {this.ids = const [], this.names = const []});

  final HealthSetupStatus status;
  final List<T> ids;
  final List<String> names;

  bool matches(HealthSetupStep<T> other) {
    if (status != other.status ||
        !ids.toSet().containsAll(other.ids) ||
        !other.ids.toSet().containsAll(ids)) {
      return false;
    }
    final normalizedNames = names.map((name) => unorm.nfc(name.trim())).toSet();
    final otherNames =
        other.names.map((name) => unorm.nfc(name.trim())).toSet();
    return normalizedNames.length == otherNames.length &&
        normalizedNames.containsAll(otherNames);
  }
}

class HealthSetupSnapshot {
  const HealthSetupSnapshot(this.revision, this.allergies, this.conditions,
      [this.physiological =
          const HealthSetupStep<int>(HealthSetupStatus.unreported)]);
  final String revision;
  final HealthSetupStep<String> allergies;

  /// Chronic diseases ("bệnh nền") only.
  final HealthSetupStep<int> conditions;

  /// Pregnancy, breastfeeding: catalog-only, no custom names.
  final HealthSetupStep<int> physiological;

  /// Every required step has an answer. The physiological step is not asked of men
  /// (`gender == 'nam'`), so it does not count for them (Q7).
  bool isComplete({String? gender}) =>
      allergies.status != HealthSetupStatus.unreported &&
      conditions.status != HealthSetupStatus.unreported &&
      (gender == 'nam' || physiological.status != HealthSetupStatus.unreported);
}

class HealthSetupOption<T> {
  const HealthSetupOption(this.id, this.name, {this.category});
  final T id;
  final String name;
  final String? category;
}
