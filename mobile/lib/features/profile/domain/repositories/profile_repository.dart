import '../entities/condition.dart';
import '../entities/health_profile.dart';

abstract interface class ProfileRepository {
  Future<HealthProfile> fetch();
  Future<void> update(ProfileDraft draft);
  Future<ConditionPage> catalog({required int offset, int limit = 20});
  Future<ProfileCondition> addCondition(int conditionId);
  Future<ProfileCondition> updateCondition(
      int linkId, Map<String, String?> changes);
  Future<void> deleteCondition(int linkId);
}
