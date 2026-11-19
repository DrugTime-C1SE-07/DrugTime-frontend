import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/data/patient_monitor_repository.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_models.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';

final now = DateTime.utc(2026, 11, 19, 2);
const summary = AdherenceSummary(
    total: 0, taken: 0, late: 0, missed: 0, pending: 0, counted: 0, rate: null);
MonitorSnapshot snapshot(String id) => MonitorSnapshot(
    id,
    [],
    MonitorHistory(
        AdherenceHistory(
            patientId: id,
            from: monitorDay(now),
            to: monitorDay(now),
            asOf: now,
            summary: summary,
            groups: []),
        null),
    []);

class MonitorRepo extends PatientMonitorRepository {
  MonitorRepo() : super(ApiClient(baseUrl: Uri.parse('https://test.invalid')));
  List<LinkedPatient> directory = const [
    LinkedPatient(id: 'mother', name: 'Hoa'),
    LinkedPatient(id: 'father', name: 'Minh')
  ];
  final pending = <String, Completer<MonitorSnapshot>>{};
  bool unavailable = false;
  DateTime? requestedFrom, requestedTo;
  @override
  Future<List<LinkedPatient>> patients() async {
    if (unavailable) throw const ApiException('Unavailable', statusCode: 503);
    return directory;
  }

  @override
  Future<MonitorSnapshot> today(String patientId,
          {required DateTime now, bool includeMedications = true}) =>
      pending[patientId]?.future ?? Future.value(snapshot(patientId));
  @override
  Future<MonitorHistory> history(
      String patientId, DateTime from, DateTime to) async {
    requestedFrom = from;
    requestedTo = to;
    return snapshot(patientId).report;
  }
}

void main() {
  test(
      'one revoked summary does not cancel other patients or restore revoked data',
      () async {
    final repo = MonitorRepo();
    repo.pending['mother'] = Completer();
    repo.pending['father'] = Completer();
    final controller = PatientMonitorController(repo, clock: () => now);
    controller.setSession('Nam', available: true);
    controller.setHubActive(true);
    await Future<void>.delayed(Duration.zero);
    repo.pending['mother']!
        .completeError(const ApiException('denied', statusCode: 403));
    await Future<void>.delayed(Duration.zero);
    repo.pending['father']!.complete(snapshot('father'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.linked.hasPatient('mother'), isFalse);
    expect(controller.summaries.containsKey('mother'), isFalse);
    expect(controller.summaries['father']?.patientId, 'father');
    controller.dispose();
  });
  test('late mother response cannot populate father after switching', () async {
    final repo = MonitorRepo();
    final c = PatientMonitorController(repo, clock: () => now);
    c.setSession('Nam', available: true);
    await c.loadHub();
    repo.pending['mother'] = Completer();
    final old = c.select('mother');
    await c.select('father');
    repo.pending['mother']!.complete(snapshot('mother'));
    await old;
    expect(c.snapshot?.patientId, 'father');
    c.dispose();
  });

  test('background offline logout clear all sources and discard delayed reads',
      () async {
    for (final session in <String?>['Nam', null]) {
      final repo = MonitorRepo();
      final controller = PatientMonitorController(repo, clock: () => now);
      controller.setSession('Nam', available: true);
      await controller.loadHub();
      repo.pending['mother'] = Completer();
      final pending = controller.select('mother');
      controller.setSession(session, available: false);
      repo.pending['mother']!.complete(snapshot('mother'));
      await pending;
      expect(controller.snapshot, isNull);
      expect(controller.patientId, isNull);
      expect(controller.linked.patients, isEmpty);
      expect(controller.summaries, isEmpty);
      expect(controller.range, isNull);
      expect(controller.interactions, isNull);
      expect(controller.food, isNull);
      controller.dispose();
    }
  });

  test(
      '503 list error preserves existing directory and is not an empty success',
      () async {
    final repo = MonitorRepo();
    final controller = PatientMonitorController(repo, clock: () => now);
    controller.setSession('Nam', available: true);
    await controller.loadHub();
    repo.unavailable = true;
    await controller.loadHub();
    expect(controller.hubError, isNotNull);
    expect(controller.linked.patients.length, 2);
    controller.dispose();
  });

  test(
      'successful directory removal and explicit 403 clear selected health immediately',
      () async {
    final repo = MonitorRepo();
    final controller = PatientMonitorController(repo, clock: () => now);
    controller.setSession('Nam', available: true);
    await controller.loadHub();
    await controller.select('mother');
    repo.directory = const [LinkedPatient(id: 'father')];
    await controller.loadHub();
    expect(controller.denied, isTrue);
    expect(controller.snapshot, isNull);
    expect(controller.linked.hasPatient('father'), isTrue);
    controller.dispose();
  });

  test('history is bounded by server date request window and never future',
      () async {
    final repo = MonitorRepo();
    final controller = PatientMonitorController(repo, clock: () => now);
    controller.setSession('Nam', available: true);
    await controller.loadHub();
    await controller.select('mother');
    await controller.loadHistory(DateTime.utc(2020), DateTime.utc(2028));
    expect(repo.requestedTo, monitorDay(now));
    expect(
        repo.requestedFrom, monitorDay(now).subtract(const Duration(days: 89)));
    controller.dispose();
  });
}
