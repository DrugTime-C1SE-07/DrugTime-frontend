import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/repositories/demo_adherence_history_repository.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_demo_preset.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';

void main() {
  Future<AdherenceHistory> fetch(DemoAdherenceHistoryRepository repo,
          {DateTime? to}) =>
      repo.fetch(
          from: DateTime.utc(2026, 10),
          to: to ?? DateTime.utc(2026, 10, 22),
          mode: HistoryMode.date);
  test('memory repository validates range and typed failures', () async {
    final repo = DemoAdherenceHistoryRepository(AdherenceDemoPreset.mixed);
    expect((await fetch(repo)).dates.last.summary.rate, 80);
    await expectLater(fetch(repo, to: DateTime.utc(2026, 10, 23)),
        throwsA(isA<HistoryFailure>()));
    repo.close();
    await expectLater(fetch(repo), throwsA(isA<HistoryFailure>()));
    final error =
        DemoAdherenceHistoryRepository(AdherenceDemoPreset.networkError);
    await expectLater(
        fetch(error),
        throwsA(isA<HistoryFailure>()
            .having((e) => e.kind, 'kind', HistoryFailureKind.network)));
    error.close();
  });
  test('loading has no timer and close completes pending safely', () async {
    final repo = DemoAdherenceHistoryRepository(AdherenceDemoPreset.loading);
    final request = fetch(repo);
    final assertion = expectLater(request, throwsA(isA<HistoryFailure>()));
    repo.close();
    await assertion;
  });
}
