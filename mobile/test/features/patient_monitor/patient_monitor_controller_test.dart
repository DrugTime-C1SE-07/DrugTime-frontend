import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_digest.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/entities/interaction_check_result.dart';
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
  InteractionCheckResult? interactionResponse;
  Map<String, dynamic>? foodResponse;
  Object? interactionError;
  Object? foodError;
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

  @override
  Future<InteractionCheckResult> interactions(String patientId) async {
    if (interactionError != null) throw interactionError!;
    return interactionResponse ??
        const InteractionCheckResult(
            status: InteractionCheckStatus.noneFound, interactions: []);
  }

  @override
  Future<Map<String, dynamic>> foodInteractions(String patientId) async {
    if (foodError != null) throw foodError!;
    return foodResponse ??
        {
          'patient_id': patientId,
          'status': 'da_kiem_tra_khong_thay',
          'disclaimer': 'Thông tin tham khảo',
          'medications': const <Map<String, dynamic>>[],
        };
  }
}

/// 09:00 VN ngày 19/11 — Losartan 06:30 bỏ lỡ, Vitamin 07:00 đã uống, Metformin 12:00 sắp tới.
final attentionNow = DateTime.utc(2026, 11, 19, 2);
final losartanAt = DateTime.utc(2026, 11, 18, 23, 30);

/// Repository có HTTP giả: chỉ endpoint trạng thái nhắc đi qua mạng giả.
class ReceiptRepo extends PatientMonitorRepository {
  ReceiptRepo(this.respond)
      : super(ApiClient(
            baseUrl: Uri.parse('https://test.invalid'),
            httpClient: MockClient((request) async {
              statusCalls.add(request.url.queryParameters['schedule_id']!);
              return respond(request);
            })));

  final Future<http.Response> Function(http.Request) respond;
  static final statusCalls = <String>[];

  @override
  Future<List<LinkedPatient>> patients() async =>
      const [LinkedPatient(id: 'mother', name: 'Hoa')];

  @override
  Future<MonitorSnapshot> today(String patientId,
      {required DateTime now, bool includeMedications = true}) async {
    AdherenceDose d(int id, String name, DateTime at, AdherenceDoseStatus s,
            [DateTime? taken]) =>
        AdherenceDose(
            medicationId: id,
            medicationName: name,
            scheduleId: id,
            scheduledAt: at,
            takenAt: taken,
            status: s);
    final day = monitorDay(attentionNow);
    return MonitorSnapshot(
        patientId,
        const [],
        MonitorHistory(
            AdherenceHistory(
                patientId: patientId,
                from: day,
                to: day,
                asOf: attentionNow,
                summary: summary,
                groups: [
                  AdherenceDateGroup(date: day, summary: summary, doses: [
                    d(1, 'Losartan', losartanAt, AdherenceDoseStatus.missed),
                    d(2, 'Vitamin', DateTime.utc(2026, 11, 19),
                        AdherenceDoseStatus.taken, DateTime.utc(2026, 11, 19)),
                    d(3, 'Metformin', DateTime.utc(2026, 11, 19, 5),
                        AdherenceDoseStatus.pending),
                  ])
                ]),
            null),
        const []);
  }
}

String statusBody({bool reminded = false}) => jsonEncode({
      'patient_id': 'mother',
      'schedule_id': 1,
      'scheduled_at': losartanAt.toIso8601String(),
      'last_reminder': reminded
          ? {
              'id': 7,
              'patient_id': 'mother',
              'schedule_id': 1,
              'scheduled_at': losartanAt.toIso8601String(),
              'requested_at':
                  DateTime.utc(2026, 11, 19, 1, 15).toIso8601String(),
              'next_allowed_at':
                  DateTime.utc(2026, 11, 19, 1, 25).toIso8601String(),
              'status': 'dispatched',
            }
          : null,
    });

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('trạng thái nhắc của liều cần chú ý (AC6, AC9)', () {
    setUp(ReceiptRepo.statusCalls.clear);

    test('chỉ hỏi trạng thái cho liều bỏ lỡ; đã có nhắc → nudged', () async {
      final c = PatientMonitorController(
          ReceiptRepo((_) async => http.Response(
              statusBody(reminded: true), 200,
              headers: {'content-type': 'application/json'})),
          clock: () => attentionNow);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await settle();
      expect(ReceiptRepo.statusCalls, ['1']);
      expect(c.attentionDoses.map((d) => d.scheduleId), [1]);
      expect(c.careMoodToday, CareMood.nudged);
      c.dispose();
    });

    test('chưa có nhắc → missed', () async {
      final c = PatientMonitorController(
          ReceiptRepo((_) async => http.Response(statusBody(), 200,
              headers: {'content-type': 'application/json'})),
          clock: () => attentionNow);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await settle();
      expect(c.careMoodToday, CareMood.missed);
      c.dispose();
    });

    test('403 khi hỏi trạng thái nhắc → thu hồi, xóa dữ liệu phiên', () async {
      final c = PatientMonitorController(
          ReceiptRepo((_) async => http.Response(
              jsonEncode({'detail': 'khong_co_quyen'}), 403,
              headers: {'content-type': 'application/json'})),
          clock: () => attentionNow);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await settle();
      expect(c.denied, isTrue);
      expect(c.snapshot, isNull);
      expect(c.careMoodToday, isNull);
      expect(c.reminders.receipt((1, losartanAt)), isNull);
      expect(c.linked.hasPatient('mother'), isFalse);
      c.dispose();
    });
  });

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

  group('loadInteractions (PB27 5.22 & PB28 5.25)', () {
    test('TC-FE-03: tải thành công drug-drug và food-warning điền đủ dữ liệu',
        () async {
      final repo = MonitorRepo()
        ..interactionResponse = const InteractionCheckResult(
          status: InteractionCheckStatus.found,
          interactions: [
            InteractionFinding(
              ingredientAId: 1,
              ingredientAName: 'Warfarin',
              ingredientBId: 2,
              ingredientBName: 'Aspirin',
              severityLevel: 4,
              interactionType: 'chong_chi_dinh',
              handlingType: 'tranh_phoi_hop',
              description: 'Nguy cơ chảy máu nặng.',
              warningMessage: 'Tránh phối hợp.',
              source: 'Dược thư',
            ),
          ],
        )
        ..foodResponse = {
          'patient_id': 'mother',
          'status': 'co_tuong_tac',
          'disclaimer': 'Thông tin tham khảo',
          'medications': const [],
        };
      final c = PatientMonitorController(repo, clock: () => now);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await c.loadInteractions();
      expect(c.denied, isFalse);
      expect(c.interactionError, isNull);
      expect(c.interactions?.status, InteractionCheckStatus.found);
      expect(c.interactions?.interactions.length, 1);
      expect(c.food?['status'], 'co_tuong_tac');
      c.dispose();
    });

    test('TC-FE-05a: 403 từ drug-drug interaction gọi revoke ngay lập tức',
        () async {
      final repo = MonitorRepo()
        ..interactionError = const ApiException('khong_co_quyen', statusCode: 403);
      final c = PatientMonitorController(repo, clock: () => now);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await c.loadInteractions();
      expect(c.denied, isTrue);
      expect(c.interactions, isNull);
      expect(c.food, isNull);
      expect(c.snapshot, isNull);
      expect(c.linked.hasPatient('mother'), isFalse);
      c.dispose();
    });

    test('TC-FE-05b: 403 từ food-warning sau khi drug-drug 200 vẫn revoke ngay',
        () async {
      final repo = MonitorRepo()
        ..foodError = const ApiException('khong_co_quyen', statusCode: 403);
      final c = PatientMonitorController(repo, clock: () => now);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await c.loadInteractions();
      expect(c.denied, isTrue);
      expect(c.interactions, isNull);
      expect(c.food, isNull);
      expect(c.snapshot, isNull);
      expect(c.linked.hasPatient('mother'), isFalse);
      c.dispose();
    });

    test('TC-FE-06a: lỗi 500 gán interactionError và giữ nguyên phiên', () async {
      final repo = MonitorRepo()
        ..interactionError = const ApiException('server_error', statusCode: 500);
      final c = PatientMonitorController(repo, clock: () => now);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await c.loadInteractions();
      expect(c.denied, isFalse);
      expect(c.interactions, isNull);
      expect(c.food, isNull);
      expect(c.interactionError, 'Chưa tải đủ kết quả tương tác.');
      c.dispose();
    });

    test('TC-FE-06b: FormatException từ food-warning gán thông báo dữ liệu lỗi',
        () async {
      final repo = MonitorRepo()
        ..foodError = const FormatException('Unexpected food report');
      final c = PatientMonitorController(repo, clock: () => now);
      c.setSession('Nam', available: true);
      await c.loadHub();
      await c.select('mother');
      await c.loadInteractions();
      expect(c.denied, isFalse);
      expect(c.interactions, isNull);
      expect(c.food, isNull);
      expect(c.interactionError, 'Kết quả không hợp lệ.');
      c.dispose();
    });
  });
}
