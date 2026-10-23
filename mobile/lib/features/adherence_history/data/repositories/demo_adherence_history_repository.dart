import 'dart:async';
import '../../domain/entities/adherence_demo_preset.dart';
import '../../domain/entities/adherence_history.dart';
import '../../domain/entities/adherence_history_failure.dart';
import '../../domain/repositories/adherence_history_repository.dart';
import '../models/adherence_demo_fixtures.dart';

class DemoAdherenceHistoryRepository implements AdherenceHistoryRepository {
  DemoAdherenceHistoryRepository(this.preset, {DateTime? clock})
      : clock = clock ?? preset.clock;
  final DateTime clock;
  final AdherenceDemoPreset preset;
  final _pending = <Completer<AdherenceHistory>>{};
  bool _closed = false;

  @override
  Future<AdherenceHistory> fetch(
      {required DateTime from,
      required DateTime to,
      required HistoryMode mode}) async {
    if (_closed) throw const HistoryFailure(HistoryFailureKind.unavailable);
    if (preset == AdherenceDemoPreset.networkError) {
      throw const HistoryFailure(HistoryFailureKind.network);
    }
    // Validate even the loading scenario without starting external work.
    final data = AdherenceDemoFixtures.build(preset,
        from: from, to: to, mode: mode, clock: clock);
    if (preset != AdherenceDemoPreset.loading) return data;
    final pending = Completer<AdherenceHistory>();
    _pending.add(pending);
    try {
      return await pending.future;
    } finally {
      _pending.remove(pending);
    }
  }

  void close() {
    _closed = true;
    for (final pending in _pending.toList()) {
      pending
          .completeError(const HistoryFailure(HistoryFailureKind.unavailable));
    }
    _pending.clear();
  }
}
