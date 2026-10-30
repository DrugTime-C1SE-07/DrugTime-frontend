import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history_failure.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';
import 'adherence_history_test_helpers.dart';

void main() {
  late FakeHistoryRepository repo;
  late AdherenceHistoryController c;
  setUp(() {
    repo = FakeHistoryRepository();
    c = AdherenceHistoryController(repo, clock: () => historyNow)
      ..setPatient('one');
  });
  tearDown(() => c.dispose());
  test('today is selected, same-month day is inline, crossing month reloads',
      () async {
    await c.load();
    expect(c.selectedDay, DateTime.utc(2026, 10, 21));
    final revision = c.accessRevision;
    await c.selectDay(DateTime.utc(2026, 10, 19));
    expect(repo.calls.length, 1);
    expect(c.selectedGroup?.doses.length, 4);
    await c.selectDay(DateTime.utc(2026, 9, 30));
    expect(c.selectedDay, DateTime.utc(2026, 9, 30));
    expect(c.selectedMonth, DateTime.utc(2026, 9));
    expect(repo.calls.last.to, DateTime.utc(2026, 9, 30));
    expect(c.accessRevision, revision);
    await c.selectDay(DateTime.utc(2026, 10, 22));
    expect(c.selectedDay, DateTime.utc(2026, 9, 30));
    await c.changeMonth(1);
    expect(c.selectedDay, c.today);
    await c.changeMonth(-1);
    expect(c.selectedDay, DateTime.utc(2026, 9, 1));
  });
  test('mode back preserves chosen day and reloads date groups', () async {
    await c.load();
    await c.selectDay(DateTime.utc(2026, 10, 19));
    await c.changeMode(HistoryMode.medication);
    expect(c.selectedDay, DateTime.utc(2026, 10, 19));
    await c.changeMode(HistoryMode.date);
    expect(repo.calls.last.mode, HistoryMode.date);
    expect(c.selectedGroup?.doses.length, 4);
    final revision = c.accessRevision;
    c.revoke();
    expect(c.accessRevision, greaterThan(revision));
    expect(c.history, isNull);
  });
  test('old account completion cannot replace new account data', () async {
    repo.delayed = true;
    final old = c.load();
    c.setPatient('two');
    final fresh = c.load();
    repo.pending[1].complete(
        AdherenceHistoryApiMapper.parse(historyFixture(patient: 'two')));
    await fresh;
    repo.pending[0].complete(AdherenceHistoryApiMapper.parse(historyFixture()));
    await old;
    expect(c.history?.patientId, 'two');
  });
  test('completion after dispose does not notify or restore data', () async {
    final delayed = FakeHistoryRepository()..delayed = true;
    final d = AdherenceHistoryController(delayed, clock: () => historyNow)
      ..setPatient('one');
    var notifications = 0;
    d.addListener(() => notifications++);
    final pending = d.load();
    d.dispose();
    final before = notifications;
    delayed.pending.single
        .complete(AdherenceHistoryApiMapper.parse(historyFixture()));
    await pending;
    expect(d.history, isNull);
    expect(notifications, before);
  });
  test('default range, switch mode keeps month, no future month', () async {
    await c.load();
    expect(repo.calls.single.to, DateTime.utc(2026, 10, 21));
    await c.changeMonth(-1);
    expect(repo.calls.last.to, DateTime.utc(2026, 9, 30));
    await c.changeMode(HistoryMode.medication);
    expect(c.selectedMonth, DateTime.utc(2026, 9));
    expect(repo.calls.last.mode, HistoryMode.medication);
    await c.changeMonth(2);
    expect(c.selectedMonth, DateTime.utc(2026, 9));
  });
  test(
      'latest read wins, data clears before next request and old error ignored',
      () async {
    await c.load();
    repo.delayed = true;
    final first = c.load();
    expect(c.history, isNull);
    final second = c.changeMode(HistoryMode.medication);
    repo.pending[1].complete(AdherenceHistoryApiMapper.parse(
        historyFixture(mode: HistoryMode.medication)));
    await second;
    repo.pending[0]
        .completeError(const HistoryFailure(HistoryFailureKind.network));
    await first;
    expect(c.history?.mode, HistoryMode.medication);
    expect(c.error, isNull);
  });
  test('content changes do not replay on group toggles', () async {
    await c.load();
    final loaded = c.contentRevision;
    c.toggleMedication(7);
    expect(c.contentRevision, loaded);
    await c.selectDay(DateTime.utc(2026, 10, 19));
    expect(c.contentRevision, greaterThan(loaded));
    final selected = c.contentRevision;
    await c.selectDay(DateTime.utc(2026, 10, 19));
    expect(c.contentRevision, selected);
  });
  test('revocation and account switch invalidate old completions', () async {
    repo.delayed = true;
    final first = c.load();
    c.revoke();
    repo.pending.single
        .complete(AdherenceHistoryApiMapper.parse(historyFixture()));
    await first;
    expect(c.history, isNull);
    expect(c.error?.kind, HistoryFailureKind.consent);
    c.setPatient('two');
    repo.delayed = false;
    await c.load();
    expect(c.error?.kind, HistoryFailureKind.invalidResponse);
    expect(c.history, isNull);
  });
  test(
      'forbidden clears data, later successful reload and independent expansion',
      () async {
    await c.load();
    c.toggleMedication(7);
    expect(c.expanded(7), isTrue);
    c.toggleMedication(8);
    c.toggleMedication(7);
    expect(c.expanded(7), isFalse);
    expect(c.expanded(8), isTrue);
    repo.failure = const HistoryFailure(HistoryFailureKind.forbidden);
    await c.load();
    expect(c.history, isNull);
    expect(c.error?.removesAccess, isTrue);
    repo.failure = null;
    await c.load();
    expect(c.history, isNotNull);
  });
}
