import 'dart:async';

import 'package:drugtime_mobile/features/adherence/data/models/adherence_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_failure.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence/domain/repositories/adherence_repository.dart';
import 'package:drugtime_mobile/features/adherence/presentation/state/adherence_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../adherence/adherence_api_mapper_test.dart'
    show sampleHistoryJson, samplePatientId;

class PendingFamilyHistory implements AdherenceRepository {
  final patients = <String>[];
  final pending = <Completer<AdherenceHistory>>[];

  @override
  Future<AdherenceHistory> fetch({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) {
    patients.add(patientId);
    final completer = Completer<AdherenceHistory>();
    pending.add(completer);
    return completer.future;
  }
}

AdherenceHistory familyHistory({String patientId = samplePatientId}) =>
    AdherenceApiMapper.history(sampleHistoryJson(patientId: patientId));

void main() {
  late PendingFamilyHistory repo;
  late AdherenceController controller;
  setUp(() {
    repo = PendingFamilyHistory();
    controller = AdherenceController(repo,
        patientId: samplePatientId, now: () => DateTime.utc(2026, 10, 22, 5));
  });
  tearDown(() => controller.dispose());

  for (final kind in [
    AdherenceFailureKind.denied,
    AdherenceFailureKind.network,
    AdherenceFailureKind.unauthorized,
  ]) {
    test('AC6: refresh clears RAM before $kind and accepts no stale success',
        () async {
      final initial = controller.load();
      repo.pending[0].complete(familyHistory());
      await initial;
      expect(controller.history, isNotNull);
      final oldRequest = controller.refresh();
      final latest = controller.refresh();
      expect(controller.history, isNull);
      repo.pending[2].completeError(AdherenceFailure(kind));
      await latest;
      repo.pending[1].complete(familyHistory());
      await oldRequest;
      expect(controller.history, isNull);
      expect(controller.failure?.kind, kind);
      expect(controller.loading, isFalse);
    });
  }

  test(
      'AC6: switching patient clears visible history and rejects the old result',
      () async {
    final initial = controller.load();
    repo.pending[0].complete(familyHistory());
    await initial;
    final oldRequest = controller.refresh();
    const other = '22222222-2222-4222-8222-222222222222';
    final changed = controller.changePatient(other);
    expect(controller.history, isNull);
    repo.pending[2].complete(familyHistory(patientId: other));
    await changed;
    repo.pending[1].complete(familyHistory());
    await oldRequest;
    expect(controller.history?.patientId, other);
    expect(repo.patients, [samplePatientId, samplePatientId, other]);
  });

  test('AC6: clear invalidates an in-flight read without an automatic refetch',
      () async {
    final first = controller.load();
    controller.clear();
    repo.pending.single.complete(familyHistory());
    await first;
    expect(controller.history, isNull);
    expect(controller.failure, isNull);
    expect(controller.loading, isFalse);
    expect(repo.patients, hasLength(1));
  });

  test('AC4: the controller also rejects a mismatched patient from its reader',
      () async {
    final read = controller.load();
    repo.pending.single.complete(
        familyHistory(patientId: '22222222-2222-4222-8222-222222222222'));
    await read;
    expect(controller.history, isNull);
    expect(controller.failure?.kind, AdherenceFailureKind.invalidResponse);
  });
}
