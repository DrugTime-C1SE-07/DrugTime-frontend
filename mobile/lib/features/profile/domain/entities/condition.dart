class ProfileCondition {
  const ProfileCondition(
      {required this.id,
      required this.conditionId,
      required this.name,
      this.subtype,
      this.stage});
  final int id;
  final int conditionId;
  final String name;
  final String? subtype;
  final String? stage;
}

class ConditionItem {
  const ConditionItem(this.id, this.name);
  final int id;
  final String name;
}

class ConditionPage {
  const ConditionPage(
      {required this.items, required this.total, required this.offset});
  final List<ConditionItem> items;
  final int total;
  final int offset;
}
