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
  const HealthSetupSnapshot(this.revision, this.allergies, this.conditions);
  final String revision;
  final HealthSetupStep<String> allergies;
  final HealthSetupStep<int> conditions;
}

class HealthSetupOption<T> {
  const HealthSetupOption(this.id, this.name, {this.category});
  final T id;
  final String name;
  final String? category;
}
