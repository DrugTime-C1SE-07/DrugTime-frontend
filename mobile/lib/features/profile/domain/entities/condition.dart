/// Catalog classification of a condition (API `category`).
///
/// Pregnancy and breastfeeding are physiological states, not chronic diseases: they are
/// shown on their own screen and never counted as "bệnh nền".
enum ConditionCategory {
  chronicDisease('chronic_disease'),
  physiologicalState('physiological_state');

  const ConditionCategory(this.api);
  final String api;

  /// Missing category (older backend) is treated as a chronic disease, as before.
  static ConditionCategory fromApi(Object? value) => switch (value) {
        null || 'chronic_disease' => chronicDisease,
        'physiological_state' => physiologicalState,
        _ => throw const FormatException('Unknown condition category'),
      };
}

class ProfileCondition {
  const ProfileCondition(
      {required this.id,
      required this.conditionId,
      required this.name,
      this.subtype,
      this.stage,
      this.category = ConditionCategory.chronicDisease});
  final int id;
  final int conditionId;
  final String name;
  final String? subtype;
  final String? stage;
  final ConditionCategory category;
}

class ConditionItem {
  const ConditionItem(this.id, this.name,
      [this.category = ConditionCategory.chronicDisease]);
  final int id;
  final String name;
  final ConditionCategory category;
}

class ConditionPage {
  const ConditionPage(
      {required this.items, required this.total, required this.offset});
  final List<ConditionItem> items;
  final int total;
  final int offset;
}
