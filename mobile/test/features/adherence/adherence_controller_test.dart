import 'dart:async';

import 'package:drugtime_mobile/features/adherence/data/models/adherence_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_failure.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence/domain/repositories/adherence_repository.dart';
import 'package:drugtime_mobile/features/adherence/presentation/state/adherence_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'adherence_api_mapper_test.dart' show sampleHistoryJson, samplePatientId;

class _PendingRepository implements AdherenceRepository {
  final requests = <({String patientId, DateTime from, DateTime to})>[];
  final pending = <Completer<AdherenceHistory>>[];

  @override
  Future<AdherenceHistory> fetch({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) {
    requests.add((patientId: patientId, from: from, to: to));
    final completer = Completer<AdherenceHistory>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  late _PendingRepository repo;
  late AdherenceController controller;
  setUp(() {
    repo = _PendingRepository();
    controller = AdherenceController(
      repo,
      patientId: samplePatientId,
      now: () => DateTime.utc(2026, 10, 22, 5),
    );
  });
  tearDown(() => controller.dispose());

  test('loads only the selected month bounded by Vietnam today', () async {
    final result = controller.load();
    expect(repo.requests.single.from, DateTime.utc(2026, 10, 1));
    expect(repo.requests.single.to, DateTime.utc(2026, 10, 22));
    expect(controller.loading, isTrue);
    repo.pending.single
        .complete(AdherenceApiMapper.history(sampleHistoryJson()));
    await result;
    expect(controller.history?.groups.single.doses, hasLength(4));
    expect(controller.selectedGroup?.date, DateTime.utc(2026, 10, 22));
  });

  test('clears data before refresh and on 403', () async {
    final first = controller.load();
    repo.pending[0].complete(AdherenceApiMapper.history(sampleHistoryJson()));
    await first;
    expect(controller.history, isNotNull);

    final refresh = controller.refresh();
    expect(controller.history, isNull);
    expect(controller.loading, isTrue);
    repo.pending[1]
        .completeError(const AdherenceFailure(AdherenceFailureKind.denied));
    await refresh;
    expect(controller.history, isNull);
    expect(controller.denied, isTrue);
  });

  test('changing patient discards late response from previous patient',
      () async {
    final first = controller.load();
    const otherPatient = '22222222-2222-4222-8222-222222222222';
    final second = controller.changePatient(otherPatient);
    expect(controller.history, isNull);
    expect(repo.requests.last.patientId, otherPatient);
    repo.pending[1].complete(
        AdherenceApiMapper.history(sampleHistoryJson(patientId: otherPatient)));
    await second;
    repo.pending[0].complete(AdherenceApiMapper.history(sampleHistoryJson()));
    await first;
    expect(controller.history?.patientId, otherPatient);
  });

  test('rejects future and out-of-range dates without a request', () async {
    expect(await controller.selectDate(DateTime.utc(2026, 10, 23)), isFalse);
    expect(await controller.selectDate(DateTime.utc(2026, 7, 1)), isFalse);
    expect(repo.requests, isEmpty);
  });
}
