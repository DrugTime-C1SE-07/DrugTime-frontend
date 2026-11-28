import 'dart:async';
import 'dart:convert';

import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/garden/care_garden.dart';
import 'package:drugtime_mobile/features/family_link/presentation/garden/garden_mood.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/entities/interaction_check_result.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/patient_monitor/data/patient_monitor_repository.dart';
import 'package:drugtime_mobile/features/patient_monitor/domain/monitor_models.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'patient_monitor_controller_test.dart' show MonitorRepo, now;

/// Giờ VN ngày [day] → UTC.
DateTime vn(int day, int h, [int m = 0]) =>
    DateTime.utc(2026, 11, day, h, m).subtract(const Duration(hours: 7));

/// 09:00 VN ngày 19/11 (= `now` của test controller).
final screenNow = now;

const _summary = AdherenceSummary(
    total: 0, taken: 0, late: 0, missed: 0, pending: 0, counted: 0, rate: null);

AdherenceDose dose(int id, String name, DateTime at,
        {AdherenceDoseStatus status = AdherenceDoseStatus.pending,
        DateTime? takenAt}) =>
    AdherenceDose(
        medicationId: id,
        medicationName: name,
        scheduleId: id,
        scheduledAt: at,
        takenAt: takenAt,
        status: status);

/// Kịch bản ngày hôm nay của Mẹ.
enum Day { ok, missed, overdue, recovered }

List<AdherenceDose> todayDoses(Day day) => [
      switch (day) {
        Day.missed => dose(1, 'Losartan 50mg', vn(19, 6, 30),
            status: AdherenceDoseStatus.missed),
        Day.overdue => dose(1, 'Losartan 50mg', vn(19, 6, 30),
            status: AdherenceDoseStatus.pending),
        Day.recovered => dose(1, 'Losartan 50mg', vn(19, 6, 30),
            status: AdherenceDoseStatus.late, takenAt: vn(19, 8, 20)),
        Day.ok => dose(1, 'Losartan 50mg', vn(19, 6, 30),
            status: AdherenceDoseStatus.taken, takenAt: vn(19, 6, 35)),
      },
      dose(2, 'Vitamin D3', vn(19, 7),
          status: AdherenceDoseStatus.taken, takenAt: vn(19, 7, 2)),
      dose(3, 'Metformin 500mg', vn(19, 12)),
      dose(4, 'Warfarin 5mg', vn(19, 20)),
    ];

/// Repository giả: dữ liệu trong bộ nhớ + HTTP giả cho endpoint nhắc liều.
class ScreenRepo extends PatientMonitorRepository {
  ScreenRepo({
    this.day = Day.missed,
    this.reminded = false,
    this.sendStatus = 201,
    this.drugResult,
    this.foodResult,
    this.drugError,
    this.foodError,
    this.interactionsGate,
  }) : super(ApiClient(
            baseUrl: Uri.parse('https://test.invalid'),
            httpClient: MockClient((r) async => _respond(r))));

  Day day;
  bool reminded;
  int sendStatus;
  InteractionCheckResult? drugResult;
  Map<String, dynamic>? foodResult;
  Object? drugError;
  Object? foodError;
  Completer<void>? interactionsGate;
  int interactionCalls = 0;
  int sends = 0, statusCalls = 0;
  static ScreenRepo? _active;
  DateTime? historyFrom, historyTo;

  static Future<http.Response> _respond(http.Request r) async =>
      _active!._handle(r);

  Map<String, dynamic> _receipt() => {
        'id': 7 + sends,
        'patient_id': 'mother',
        'schedule_id': 1,
        'scheduled_at': vn(19, 6, 30).toIso8601String(),
        'requested_at': vn(19, 8, 15).toIso8601String(),
        'next_allowed_at':
            screenNow.add(const Duration(minutes: 9)).toIso8601String(),
        'status': 'dispatched',
      };

  http.Response _json(Object body, int status) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});

  Future<http.Response> _handle(http.Request r) async {
    if (r.url.path.endsWith('/dose-reminders/status')) {
      statusCalls++;
      return _json({
        'patient_id': 'mother',
        'schedule_id': int.parse(r.url.queryParameters['schedule_id']!),
        'scheduled_at': r.url.queryParameters['scheduled_at'],
        'last_reminder': reminded ? _receipt() : null,
      }, 200);
    }
    if (r.method == 'POST' && r.url.path.endsWith('/dose-reminders')) {
      if (sendStatus == 429) {
        return http.Response(jsonEncode({'detail': 'cooldown'}), 429, headers: {
          'content-type': 'application/json',
          'retry-after': '600'
        });
      }
      if (sendStatus >= 400) return _json({'detail': 'loi'}, sendStatus);
      sends++;
      reminded = true;
      return _json(_receipt(), 201);
    }
    return _json({'detail': 'not found'}, 404);
  }

  @override
  Future<List<LinkedPatient>> patients() async {
    _active = this;
    return const [LinkedPatient(id: 'mother', name: 'Mẹ Hoa')];
  }

  AdherenceHistory _history(DateTime from, DateTime to) {
    final groups = <AdherenceDateGroup>[
      for (var d = 13; d <= 18; d++)
        AdherenceDateGroup(
            date: DateTime.utc(2026, 11, d),
            summary: _summary,
            doses: [
              dose(1, 'Losartan 50mg', vn(d, 6, 30),
                  status: d == 15
                      ? AdherenceDoseStatus.missed
                      : d == 14
                          ? AdherenceDoseStatus.late
                          : AdherenceDoseStatus.taken,
                  takenAt: d == 15 ? null : vn(d, d == 14 ? 8 : 6, 40)),
            ]),
      AdherenceDateGroup(
          date: DateTime.utc(2026, 11, 19),
          summary: _summary,
          doses: todayDoses(day)
              .where((d) => !d.scheduledAt.isAfter(screenNow))
              .toList()),
    ];
    return AdherenceHistory(
        patientId: 'mother',
        from: from,
        to: to,
        asOf: screenNow,
        summary: const AdherenceSummary(
            total: 28,
            taken: 24,
            late: 3,
            missed: 1,
            pending: 0,
            counted: 28,
            rate: 86),
        groups: groups);
  }

  @override
  Future<MonitorHistory> history(
      String patientId, DateTime from, DateTime to) async {
    historyFrom = from;
    historyTo = to;
    return MonitorHistory(_history(from, to), null);
  }

  @override
  Future<MonitorSnapshot> today(String patientId,
      {required DateTime now, bool includeMedications = true}) async {
    _active = this;
    final dayStart = monitorDay(now);
    final history =
        _history(dayStart.subtract(const Duration(days: 6)), dayStart);
    // liều tương lai không có trong lịch sử: đưa qua lịch để dosesForDay suy ra
    final schedules = [
      MonitorSchedule(3, 3, 'Metformin 500mg', '12:00', [1, 2, 3, 4, 5, 6, 7],
          DateTime.utc(2026, 1), null),
      MonitorSchedule(4, 4, 'Warfarin 5mg', '20:00', [1, 2, 3, 4, 5, 6, 7],
          DateTime.utc(2026, 1), null),
    ];
    return MonitorSnapshot(
        patientId,
        schedules,
        MonitorHistory(history, null),
        includeMedications
            ? const [
                Medication(
                    id: '1',
                    catalogId: '10',
                    name: 'Losartan',
                    activeIngredient: '',
                    strength: '50mg',
                    unit: 'viên',
                    dosePerIntake: 1,
                    frequency: DoseFrequency.once,
                    timing: IntakeTiming.anytime,
                    stockRemaining: 3),
                Medication(
                    id: '2',
                    catalogId: '11',
                    name: 'Vitamin D3',
                    activeIngredient: '',
                    strength: '',
                    unit: 'viên',
                    dosePerIntake: 1,
                    frequency: DoseFrequency.once,
                    timing: IntakeTiming.anytime,
                    stockRemaining: 25),
                Medication(
                    id: '3',
                    catalogId: '12',
                    name: 'Thuốc hết',
                    activeIngredient: '',
                    strength: '',
                    unit: 'viên',
                    dosePerIntake: 1,
                    frequency: DoseFrequency.once,
                    timing: IntakeTiming.anytime,
                    stockRemaining: 0),
              ]
            : const []);
  }

  @override
  Future<InteractionCheckResult> interactions(String patientId) async {
    interactionCalls++;
    if (interactionsGate != null) await interactionsGate!.future;
    if (drugError != null) throw drugError!;
    return drugResult ??
        const InteractionCheckResult(
            status: InteractionCheckStatus.found,
            interactions: [
              InteractionFinding(
                  ingredientAId: 1,
                  ingredientAName: 'Warfarin',
                  ingredientBId: 2,
                  ingredientBName: 'Aspirin',
                  severityLevel: 3,
                  interactionType: 'duoc_dong_hoc',
                  handlingType: 'can_theo_doi',
                  description: 'Tăng nguy cơ chảy máu.',
                  warningMessage: 'Theo dõi dấu hiệu chảy máu.',
                  source: 'Dược thư'),
            ]);
  }

  @override
  Future<Map<String, dynamic>> foodInteractions(String patientId) async {
    if (foodError != null) throw foodError!;
    return foodResult ??
        {
          'patient_id': patientId,
          'status': 'co_tuong_tac',
          'disclaimer':
              'Thông tin tham khảo — hỏi bác sĩ hoặc dược sĩ khi cần.',
          'medications': [
            {
              'medication': {'name': 'Warfarin'},
              'status': 'co_tuong_tac',
              'warnings': [
                {
                  'food_to_avoid': 'Rau nhiều vitamin K',
                  'severity_level': 3,
                  'reason': 'Làm giảm tác dụng chống đông.',
                  'source': 'Dược thư'
                }
              ]
            }
          ],
        };
  }
}

Future<PatientMonitorController> pumpMonitor(
    WidgetTester tester, ScreenRepo repo,
    {bool selectFirst = true}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // cảnh khu vườn chạy ticker liên tục: giảm chuyển động để pumpAndSettle dừng
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final controller = PatientMonitorController(repo, clock: () => screenNow);
  final invites = InviteLinkController();
  addTearDown(controller.dispose);
  addTearDown(invites.dispose);
  controller.setSession('Nam', available: true);
  await controller.loadHub();
  if (selectFirst) await controller.select('mother');
  await tester.pumpWidget(FamilyLinkScope(
      repository: InMemoryFamilyLinkRepository(),
      caregivers: InMemoryCaregiverRepository(),
      invites: invites,
      monitor: controller,
      child: MaterialApp(
          theme: buildAppTheme(),
          home: const PatientMonitorScreen(patientId: 'mother'))));
  await tester.pumpAndSettle();
  return controller;
}

GardenMood gardenMood(WidgetTester tester) =>
    tester.widget<CareGarden>(find.byKey(const Key('today-garden'))).mood;

void main() {
  testWidgets(
      'R2a: hôm nay ổn — không có card trạng thái, cảnh vui, không nút gọi/bữa ăn',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.ok));
    expect(find.text('Mẹ Hoa'), findsOneWidget);
    expect(find.text('Đang xem · chỉ xem'), findsOneWidget);
    expect(find.text('2/4 liều'), findsOneWidget);
    expect(find.byKey(const ValueKey('care-none')), findsOneWidget);
    expect(gardenMood(tester), GardenMood.ok);
    expect(find.byKey(const ValueKey('dose-row-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('dose-row-4')), findsOneWidget);
    expect(find.text('Tối nay'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsNothing);
    expect(find.textContaining('Gọi'), findsNothing);
    expect(find.textContaining('Bữa ăn'), findsNothing);
    expect(find.textContaining('Đã uống hộ'), findsNothing);
    expect(find.text('5 ngày liên tục'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R2b: liều bỏ lỡ — card đỏ có độ trễ giờ VN và nút Nhắc (AC4)',
      (tester) async {
    final repo = ScreenRepo(day: Day.missed);
    await pumpMonitor(tester, repo);
    expect(find.byKey(const ValueKey('care-missed')), findsOneWidget);
    expect(find.text('Mẹ Hoa chưa uống Losartan 50mg'), findsOneWidget);
    expect(find.text('Liều 06:30 · đã trễ 2 giờ 30 phút'), findsOneWidget);
    expect(find.text('Nhắc Mẹ Hoa'), findsOneWidget);
    expect(find.text('Bỏ lỡ'), findsOneWidget);
    expect(gardenMood(tester), GardenMood.missed);
    expect(repo.statusCalls, 1);
  });

  testWidgets(
      'R2c: bấm Nhắc → đã nhắc, cooldown, toast, cảnh rung chuông (AC6, P14)',
      (tester) async {
    final repo = ScreenRepo(day: Day.missed);
    await pumpMonitor(tester, repo);
    await tester.tap(find.byKey(const Key('nudge-button')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(repo.sends, 1);
    expect(find.byKey(const Key('nudge-sent')), findsOneWidget);
    expect(find.text('Đã gửi lời nhắc tới Mẹ Hoa'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('care-nudged')), findsOneWidget);
    expect(find.text('Đã nhắc Mẹ Hoa lúc 08:15'), findsOneWidget);
    expect(find.textContaining('Nhắc lại sau'), findsOneWidget);
    final button =
        tester.widget<ButtonStyleButton>(find.byKey(const Key('nudge-button')));
    expect(button.onPressed, isNull);
    expect(gardenMood(tester), GardenMood.nudged);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'R2 quá giờ chưa xác nhận: card "chưa xác nhận", không nói "chưa uống" (review M5, QD-24/25)',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.overdue));
    expect(find.byKey(const ValueKey('care-overdue')), findsOneWidget);
    expect(find.text('Mẹ Hoa chưa xác nhận Losartan 50mg'), findsOneWidget);
    expect(find.textContaining('chưa uống'), findsNothing);
    expect(find.textContaining('quá giờ 2 giờ 30 phút'), findsOneWidget);
    expect(find.text('Chưa xác nhận'), findsOneWidget);
    expect(find.text('Nhắc Mẹ Hoa'), findsOneWidget);
  });

  testWidgets('R2c khi đã nhắc từ trước: mở màn thấy ngay trạng thái đã nhắc',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.missed, reminded: true));
    expect(find.byKey(const ValueKey('care-nudged')), findsOneWidget);
    expect(gardenMood(tester), GardenMood.nudged);
  });

  for (final status in [429, 503]) {
    testWidgets('Nhắc lỗi $status: báo lỗi, card vẫn là bỏ lỡ (AC7)',
        (tester) async {
      final repo = ScreenRepo(day: Day.missed, sendStatus: status);
      await pumpMonitor(tester, repo);
      await tester.tap(find.byKey(const Key('nudge-button')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('nudge-message')), findsOneWidget);
      expect(
          find.text(status == 429
              ? 'Chưa đến thời gian nhắc lại.'
              : 'Chưa xác nhận được yêu cầu. Bạn có thể thử lại.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('care-missed')), findsOneWidget);
      expect(find.byKey(const Key('nudge-sent')), findsNothing);
      expect(gardenMood(tester), GardenMood.missed);
    });
  }

  testWidgets(
      'R2d: uống bù — card xanh theo taken_at, chip Muộn, ăn mừng (AC5)',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.recovered));
    expect(find.byKey(const ValueKey('care-recovered')), findsOneWidget);
    expect(find.text('Mẹ Hoa đã uống Losartan 50mg lúc 08:20'), findsOneWidget);
    expect(find.text('trễ 1 giờ 50 phút'), findsOneWidget);
    expect(find.text('Muộn 08:20'), findsOneWidget);
    expect(gardenMood(tester), GardenMood.recovered);
  });

  testWidgets(
      'R3: chi tiết liều — giờ hẹn, giờ nhắc, dải 7 chấm đúng màu (AC8)',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.missed, reminded: true));
    await tester.tap(find.byKey(const ValueKey('dose-row-1')));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết liều'), findsOneWidget);
    expect(find.text('Mẹ Hoa · chỉ xem'), findsOneWidget);
    expect(find.byKey(const Key('detail-reminded')), findsOneWidget);
    expect(find.text('08:15'), findsOneWidget);
    for (final (i, mark) in [
      (0, 'onTime'),
      (1, 'late'),
      (2, 'missed'),
      (3, 'onTime'),
      (6, 'missed'),
    ]) {
      expect(find.byKey(ValueKey('strip-$i-$mark')), findsOneWidget,
          reason: 'ô $i');
    }
    expect(find.byKey(const Key('detail-nudge')), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Liều hôm nay'), findsOneWidget);
  });

  testWidgets(
      'R3 liều đã uống muộn: dòng "đã uống" có độ trễ, không có nút nhắc',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.recovered));
    await tester.tap(find.byKey(const ValueKey('dose-row-1')));
    await tester.pumpAndSettle();
    expect(find.text('08:20 · trễ 1g50'), findsOneWidget);
    expect(find.byKey(const Key('detail-nudge')), findsNothing);
  });

  testWidgets(
      'R5 + R5a: chip tồn kho ≤ 3 màu cam, banner tương tác mở chi tiết (AC13)',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.ok));
    await tester.tap(find.byKey(const Key('quick-cabinet')));
    await tester.pumpAndSettle();
    expect(find.text('Tủ thuốc'), findsOneWidget);
    expect(find.text('Còn 3 viên — sắp hết'), findsOneWidget);
    expect(find.text('Còn 25 viên'), findsOneWidget);
    expect(find.text('Hết thuốc'), findsOneWidget);
    expect(find.text('2 tương tác cần theo dõi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cabinet-interaction-banner')));
    await tester.pumpAndSettle();
    expect(find.text('Cảnh báo tương tác'), findsOneWidget);
    expect(find.text('MỨC 3'), findsNWidgets(2));
    expect(find.text('Warfarin ⇄ Aspirin'), findsOneWidget);
    expect(find.text('Tăng nguy cơ chảy máu.'), findsOneWidget);
    expect(find.text('Warfarin ⇄ Rau nhiều vitamin K'), findsOneWidget);
    expect(find.textContaining('Thông tin tham khảo'), findsOneWidget);
  });

  testWidgets(
      'R5 + R5a: trạng thái không thấy tương tác hiện banner xanh và disclaimer (TC-FE-02)',
      (tester) async {
    final repo = ScreenRepo(
      day: Day.ok,
      drugResult: const InteractionCheckResult(
        status: InteractionCheckStatus.noneFound,
        interactions: [],
      ),
      foodResult: {
        'patient_id': 'mother',
        'status': 'da_kiem_tra_khong_thay',
        'disclaimer': 'Thông tin chỉ mang tính tham khảo.',
        'medications': const <Map<String, dynamic>>[],
      },
    );
    await pumpMonitor(tester, repo);
    await tester.tap(find.byKey(const Key('quick-cabinet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cabinet-interaction-banner')), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    expect(find.text('Đã kiểm tra, không thấy tương tác'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cabinet-interaction-banner')));
    await tester.pumpAndSettle();
    expect(find.text('Cảnh báo tương tác'), findsOneWidget);
    expect(find.text('Đã kiểm tra, không thấy tương tác'), findsNWidgets(2));
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.textContaining(nfr03Disclaimer), findsOneWidget);
    expect(find.textContaining('Thông tin chỉ mang tính tham khảo.'),
        findsOneWidget);
  });

  testWidgets(
      'R5a: hiển thị đủ chỉ xem, cách giờ, thiếu dữ liệu và disclaimer bắt buộc (TC-FE-03, TC-FE-04)',
      (tester) async {
    final repo = ScreenRepo(
      day: Day.ok,
      drugResult: const InteractionCheckResult(
        status: InteractionCheckStatus.found,
        interactions: [
          InteractionFinding(
            ingredientAId: 10,
            ingredientAName: 'Ciprofloxacin',
            ingredientBId: 11,
            ingredientBName: 'Canxi',
            severityLevel: 2,
            interactionType: 'hap_thu',
            handlingType: 'cach_gio',
            minIntervalHours: 2,
            description: 'Giảm hấp thu kháng sinh.',
            warningMessage: 'Uống cách nhau tối thiểu 2 giờ.',
            source: 'Dược thư',
          ),
        ],
        insufficientDataMedications: [
          InsufficientDataMedication(
            medicationId: 99,
            medicationName: 'Thảo dược X',
            reason: 'Chưa có dữ liệu hoạt chất chuẩn',
          ),
        ],
      ),
      foodResult: {
        'patient_id': 'mother',
        'status': 'khong_du_du_lieu',
        'disclaimer': 'Thông tin tham khảo — hỏi bác sĩ hoặc dược sĩ khi cần.',
        'medications': [
          {
            'medication': {'name': 'Thảo dược X'},
            'status': 'khong_du_du_lieu',
            'warnings': const <Map<String, dynamic>>[],
          },
        ],
      },
    );
    await pumpMonitor(tester, repo);
    await tester.tap(find.text('Tương tác thuốc và thực phẩm'));
    await tester.pumpAndSettle();

    expect(find.text('Cảnh báo tương tác'), findsOneWidget);
    expect(find.textContaining('Mẹ Hoa · chỉ xem'), findsOneWidget);
    expect(find.text('MỨC 2'), findsOneWidget);
    expect(find.text('Dùng cách giờ theo hướng dẫn chuyên môn'), findsOneWidget);
    expect(find.text('Ciprofloxacin ⇄ Canxi'), findsOneWidget);
    expect(find.text('Cách nhau ít nhất 2 giờ'), findsOneWidget);
    expect(find.text('Thảo dược X: Chưa có dữ liệu hoạt chất chuẩn'),
        findsOneWidget);
    expect(find.text('Thảo dược X: Chưa đủ dữ liệu'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.textContaining('Thông tin tham khảo'), findsOneWidget);
  });

  testWidgets(
      'R5/R5a: 403 từ drug-drug hoặc food-warning chuyển ngay sang LostAccessView (TC-FE-05)',
      (tester) async {
    for (final failFood in [false, true]) {
      final repo = ScreenRepo(
        day: Day.ok,
        drugError:
            failFood ? null : const ApiException('khong_co_quyen', statusCode: 403),
        foodError:
            failFood ? const ApiException('khong_co_quyen', statusCode: 403) : null,
      );
      await pumpMonitor(tester, repo);
      await tester.tap(find.byKey(const Key('quick-cabinet')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('monitor-lost')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'R5a: trạng thái đang tải, lỗi 500 và nút Thử lại phục hồi dữ liệu (TC-FE-06)',
      (tester) async {
    final gate = Completer<void>();
    final repo = ScreenRepo(
      day: Day.ok,
      interactionsGate: gate,
      drugError: const ApiException('server_error', statusCode: 500),
    );
    await pumpMonitor(tester, repo);
    await tester.tap(find.text('Tương tác thuốc và thực phẩm'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải đủ kết quả tương tác.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    repo.drugError = null;
    repo.interactionsGate = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(repo.interactionCalls, 2);
    expect(find.text('Warfarin ⇄ Aspirin'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });

  testWidgets('R6: Tuần này ↔ Tháng 11 gọi đúng khoảng và hiện số (AC14)',
      (tester) async {
    final repo = ScreenRepo(day: Day.ok);
    await pumpMonitor(tester, repo);
    await tester.tap(find.byTooltip('Lịch sử uống thuốc'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử uống thuốc'), findsOneWidget);
    // 19/11/2026 là thứ Năm → tuần bắt đầu thứ Hai 16/11
    expect(repo.historyFrom, DateTime.utc(2026, 11, 16));
    expect(repo.historyTo, DateTime.utc(2026, 11, 19));
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('24 liều đúng giờ'), findsOneWidget);
    expect(find.text('3 liều muộn'), findsOneWidget);
    expect(find.text('1 liều bỏ lỡ'), findsOneWidget);
    expect(find.text('Hôm nay · T5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-month')));
    await tester.pumpAndSettle();
    expect(repo.historyFrom, DateTime.utc(2026, 11, 1));
    expect(repo.historyTo, DateTime.utc(2026, 11, 19));
  });

  testWidgets(
      'R8: mất quyền giữa chừng → xóa dữ liệu, chữ trung tính, về hub (AC9)',
      (tester) async {
    final controller = await pumpMonitor(tester, ScreenRepo(day: Day.missed));
    controller.revoke('mother');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monitor-lost')), findsOneWidget);
    expect(find.text('Không còn xem được'), findsOneWidget);
    expect(
        find.text('Mẹ Hoa đã dừng chia sẻ hoặc hủy liên kết.'), findsOneWidget);
    expect(find.textContaining('Losartan'), findsNothing);
    expect(find.textContaining('tự khôi phục'), findsNothing);
    expect(controller.snapshot, isNull);
    expect(tester.widget<CareGarden>(find.byKey(const Key('lost-garden'))).mood,
        GardenMood.lost);
  });

  testWidgets('giảm chuyển động: màn hôm nay không còn khung hình chạy (AC16)',
      (tester) async {
    await pumpMonitor(tester, ScreenRepo(day: Day.recovered));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
      '320dp hub with large text and duplicate long names selects by ID',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final repo = MonitorRepo()
      ..directory = const [
        LinkedPatient(
            id: 'mother', name: 'Nguyễn Thị Hoa có tên hiển thị rất dài'),
        LinkedPatient(
            id: 'father', name: 'Nguyễn Thị Hoa có tên hiển thị rất dài'),
        LinkedPatient(id: 'unnamed'),
      ];
    final controller = PatientMonitorController(repo, clock: () => now);
    final consent = ConsentController(InMemoryConsentRepository());
    final invites = InviteLinkController();
    await consent.load();
    controller.setSession('Nam', available: true);
    await tester.pumpWidget(ConsentScope(
        controller: consent,
        child: FamilyLinkScope(
            repository: InMemoryFamilyLinkRepository(),
            caregivers: InMemoryCaregiverRepository(),
            invites: invites,
            monitor: controller,
            child: MaterialApp(
                theme: buildAppTheme(),
                builder: (_, child) => MediaQuery(
                    data: const MediaQueryData(
                        textScaler: TextScaler.linear(2),
                        disableAnimations: true),
                    child: child!),
                home: const FamilyTabScreen()))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('patient-mother')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('patient-father')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('patient-father')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('patient-unnamed')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Người bệnh'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    consent.dispose();
    invites.dispose();
  });
}
