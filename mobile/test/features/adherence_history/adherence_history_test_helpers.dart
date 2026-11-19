import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/screens/adherence_history_screen.dart';
import 'package:drugtime_mobile/features/adherence_history/presentation/state/adherence_history_controller.dart';

import 'package:drugtime_mobile/features/adherence_history/data/models/adherence_history_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/repositories/adherence_history_repository.dart';

final historyNow = DateTime.utc(2026, 10, 21, 3);

Map<String, dynamic> historyFixture({
  HistoryMode mode = HistoryMode.date,
  String patient = 'one',
  String medicationName = 'Metformin 500 mg',
  List<String> statuses = const [
    'da_uong',
    'uong_tre',
    'bo_lo',
    'cho_xac_nhan'
  ],
}) {
  final counts = HistoryDoseStatus.values
      .map((s) => statuses.where((v) => v == s.wire).length)
      .toList();
  final counted = counts[0] + counts[1] + counts[2];
  final summary = <String, dynamic>{
    'total': statuses.length,
    'taken': counts[0],
    'late': counts[1],
    'missed': counts[2],
    'pending': counts[3],
    'counted': counted,
    'adherence_rate': counted == 0
        ? null
        : double.parse(
            (100 * (counts[0] + counts[1]) / counted).toStringAsFixed(2)),
  };
  final doses = <Map<String, dynamic>>[
    for (var i = 0; i < statuses.length; i++)
      {
        'medication_id': 7,
        'medication_name': medicationName,
        'schedule_id': i + 1,
        'scheduled_at': '2026-10-19T08:00:00+07:00',
        'taken_at': switch (statuses[i]) {
          'da_uong' => '2026-10-19T08:10:00+07:00',
          'uong_tre' => '2026-10-19T08:45:00+07:00',
          _ => null,
        },
        'status': statuses[i],
        'status_source':
            statuses[i] == 'cho_xac_nhan' ? 'inferred' : 'recorded',
      },
  ];
  return {
    'patient_id': patient,
    'from': '2026-10-01',
    'to': '2026-10-21',
    'group_by': mode.wire,
    'timezone': 'Asia/Ho_Chi_Minh',
    'as_of': '2026-10-21T10:00:00+07:00',
    'summary': summary,
    'groups': statuses.isEmpty
        ? <Object>[]
        : [
            {
              if (mode == HistoryMode.date) 'date': '2026-10-19',
              if (mode == HistoryMode.medication) ...{
                'medication_id': 7,
                'medication_name': medicationName,
              },
              'summary': Map<String, dynamic>.from(summary),
              'doses': doses,
            },
          ],
  };
}

Map<String, dynamic> copyFixture(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class FakeHistoryRepository implements AdherenceHistoryRepository {
  final calls = <({DateTime from, DateTime to, HistoryMode mode})>[];
  final pending = <Completer<AdherenceHistory>>[];
  bool delayed = false;
  Object? failure;
  String patient = 'one';
  String medicationName = 'Metformin 500 mg';
  AdherenceHistory Function(AdherenceHistory)? transform;
  List<String> statuses = ['da_uong', 'uong_tre', 'bo_lo', 'cho_xac_nhan'];

  @override
  Future<AdherenceHistory> fetch(
      {required DateTime from,
      required DateTime to,
      required HistoryMode mode}) async {
    calls.add((from: from, to: to, mode: mode));
    if (delayed) {
      final completer = Completer<AdherenceHistory>();
      pending.add(completer);
      return completer.future;
    }
    if (failure case final error?) throw error;
    final fixture = historyFixture(
        mode: mode,
        patient: patient,
        statuses: statuses,
        medicationName: medicationName);
    fixture['from'] = AdherenceHistoryApiMapper.dateString(from);
    fixture['to'] = AdherenceHistoryApiMapper.dateString(to);
    // Tests for selection use an empty history outside the seeded month.
    if (from.month != 10 || from.year != 2026) {
      return AdherenceHistory(
          patientId: patient,
          from: from,
          to: to,
          asOf: historyNow,
          mode: mode,
          summary: const AdherenceSummary(
              total: 0,
              taken: 0,
              late: 0,
              missed: 0,
              pending: 0,
              counted: 0,
              rate: null));
    }
    final result = AdherenceHistoryApiMapper.parse(fixture);
    return transform?.call(result) ?? result;
  }
}

Future<AdherenceHistoryController> pumpHistory(
    WidgetTester tester, FakeHistoryRepository repo,
    {double width = 375,
    double height = 1000,
    double scale = 1,
    bool reducedMotion = false,
    EdgeInsets safeInsets = EdgeInsets.zero}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AdherenceHistoryController(repo, clock: () => historyNow)
    ..setPatient('one');
  addTearDown(controller.dispose);
  await tester.pumpWidget(AdherenceHistoryScope(
      controller: controller,
      child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: reducedMotion,
                  padding: safeInsets,
                  viewPadding: safeInsets),
              child: child!),
          home: const Scaffold(body: AdherenceHistoryScreen()))));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> openHistoryMonth(WidgetTester tester) async {
  await scrollHistoryTop(tester);
  await tester.tap(find.byTooltip('Mở lịch tháng'));
  await tester.pumpAndSettle();
}

Future<void> openMedicationHistory(WidgetTester tester) async {
  await scrollHistoryTop(tester);
  await tester.tap(find.byTooltip('Tùy chọn lịch sử'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Theo thuốc'));
  await tester.pumpAndSettle();
}

Future<void> scrollHistoryTop(WidgetTester tester) async {
  final vertical = find
      .descendant(
          of: find.byType(ListView).first, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(find.byKey(const Key('history-title')), -600,
      scrollable: vertical, maxScrolls: 100);
  await tester.pumpAndSettle();
}
