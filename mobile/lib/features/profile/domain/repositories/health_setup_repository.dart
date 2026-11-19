import '../entities/health_setup.dart';

abstract interface class HealthSetupRepository {
  Future<HealthSetupSnapshot> read();
  Future<List<HealthSetupOption<String>>> allergens();
  Future<List<HealthSetupOption<int>>> conditions();

  Future<HealthSetupSnapshot> save(
    String revision, {
    HealthSetupStep<String>? allergies,
    HealthSetupStep<int>? conditions,
    HealthSetupStep<int>? physiological,
  });
}

class HealthSetupSaveException implements Exception {
  const HealthSetupSaveException({required this.needsReadback});
  final bool needsReadback;
}
