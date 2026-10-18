import 'package:drugtime_mobile/features/family/domain/entities/family_link_code.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_link_code_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements FamilyLinkCodeRepository {
  final List<Object> results = [];
  int calls = 0;

  @override
  Future<FamilyLinkCode> fetch() async {
    calls++;
    final result = results.removeAt(0);
    if (result is FamilyLinkCodeFailure) throw result;
    return result as FamilyLinkCode;
  }
}

void main() {
  test('load publishes server value and reports loading', () async {
    final repository = _FakeRepository()
      ..results.add(const FamilyLinkCode(
          code: 'A1B2C3D4E5', qrPayload: 'drugtime://link?code=A1B2C3D4E5'));
    final controller = FamilyLinkCodeController(repository);
    final observedLoading = <bool>[];
    controller.addListener(() => observedLoading.add(controller.isLoading));

    await controller.load();

    expect(repository.calls, 1);
    expect(controller.code?.code, 'A1B2C3D4E5');
    expect(controller.hasLoaded, isTrue);
    expect(observedLoading, [true, false]);
    controller.dispose();
  });

  test('failure exposes only failure kind and retry fetches fresh server value',
      () async {
    final repository = _FakeRepository()
      ..results.add(
          const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.unavailable))
      ..results.add(const FamilyLinkCode(
          code: 'F1G2H3J4K5', qrPayload: 'drugtime://link?code=F1G2H3J4K5'));
    final controller = FamilyLinkCodeController(repository);

    await controller.load();
    expect(controller.failure?.kind, FamilyLinkCodeFailureKind.unavailable);
    expect(controller.code, isNull);
    await controller.load();

    expect(repository.calls, 2);
    expect(controller.failure, isNull);
    expect(controller.code?.code, 'F1G2H3J4K5');
    controller.dispose();
  });
}
