import 'dart:async';

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/adherence/data/models/adherence_api_mapper.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_failure.dart';
import 'package:drugtime_mobile/features/adherence/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/adherence/domain/repositories/adherence_repository.dart';
import 'package:drugtime_mobile/features/adherence/presentation/screens/family_adherence_screen.dart';
import 'package:drugtime_mobile/features/adherence/presentation/widgets/adherence_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'adherence_api_mapper_test.dart' show sampleHistoryJson, samplePatientId;

class _Repository implements AdherenceRepository {
  final pending = <Completer<AdherenceHistory>>[];
  final patients = <String>[];

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

Widget _screen(_Repository repository, {String patientId = samplePatientId}) =>
    MaterialApp(
      navigatorObservers: [familyAdherenceRouteObserver],
      home: FamilyAdherenceScreen(
        patientId: patientId,
        patientName: 'Mẹ',
        repository: repository,
        now: () => DateTime.utc(2026, 10, 22, 5),
      ),
    );

void main() {
  for (final width in [320.0, 375.0]) {
    testWidgets('week and month tap targets are 48dp at ${width}dp',
        (tester) async {
      tester.view.physicalSize = Size(width, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final semantics = tester.ensureSemantics();
      try {
        DateTime? selected;
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AdherenceDatePicker(
            selectedDate: DateTime.utc(2026, 10, 22),
            earliestDate: DateTime.utc(2026, 7, 25),
            today: DateTime.utc(2026, 10, 22),
            groups: const [],
            onSelected: (date) => selected = date,
          ),
        ))));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.tap(find.text('21'));
        expect(selected, DateTime.utc(2026, 10, 21));
        await tester.tap(find.byKey(const Key('adherence-calendar-toggle')));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.ensureVisible(find.text('18'));
        await tester.tap(find.text('18'));
        expect(selected, DateTime.utc(2026, 10, 18));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
  testWidgets('shows server summary and four read-only dose states',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository));
    expect(find.text('Đang tải lịch sử tuân thủ'), findsOneWidget);
    repository.pending.single.complete(
      AdherenceApiMapper.history(sampleHistoryJson()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mẹ'), findsOneWidget);
    expect(find.text('Tỷ lệ tuân thủ (gồm uống trễ)'), findsOneWidget);
    expect(find.text('66.67%'), findsOneWidget);
    expect(find.textContaining('Đã uống'), findsWidgets);
    expect(find.textContaining('Uống trễ'), findsWidgets);
    expect(find.textContaining('Bỏ lỡ'), findsWidgets);
    expect(find.textContaining('Chờ xác nhận'), findsWidgets);
    expect(find.text('Xác nhận'), findsNothing);
    expect(find.text('Sửa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears patient details before a denied refresh', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository));
    repository.pending[0].complete(
      AdherenceApiMapper.history(sampleHistoryJson()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thuốc A'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Thuốc A'), findsNothing);
    repository.pending[1].completeError(
      const AdherenceFailure(AdherenceFailureKind.denied),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không còn quyền xem lịch sử'), findsOneWidget);
    expect(find.text('Thuốc A'), findsNothing);
  });

  testWidgets('empty response and network retry have distinct states',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository));
    repository.pending[0].complete(
      AdherenceApiMapper.history(sampleHistoryJson(empty: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có liều được tính'), findsOneWidget);
    expect(find.text('Không có lịch sử trong ngày này'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    repository.pending[1].completeError(
      const AdherenceFailure(AdherenceFailureKind.network),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa thể tải lịch sử'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(repository.pending, hasLength(3));
    repository.pending[2].complete(
      AdherenceApiMapper.history(sampleHistoryJson()),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('rejects invalid route arguments without fetching',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return TextButton(
          onPressed: () => Navigator.of(context).pushNamed(
            AppRoutes.familyAdherence,
            arguments: const FamilyAdherenceRouteArgs(patientId: 'bad-id'),
          ),
          child: const Text('Open'),
        );
      }),
      onGenerateRoute: (settings) =>
          onGenerateRoute(settings, adherenceRepository: repository),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(repository.patients, isEmpty);
    expect(find.textContaining('Chưa thể mở lịch sử'), findsOneWidget);
  });

  testWidgets('opens valid family route with supplied patient', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return TextButton(
          onPressed: () => Navigator.of(context).pushNamed(
            AppRoutes.familyAdherence,
            arguments: const FamilyAdherenceRouteArgs(
              patientId: samplePatientId,
              patientName: 'Mẹ',
            ),
          ),
          child: const Text('Open'),
        );
      }),
      onGenerateRoute: (settings) =>
          onGenerateRoute(settings, adherenceRepository: repository),
    ));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.patients, [samplePatientId]);
    expect(find.text('Mẹ'), findsOneWidget);
    repository.pending.single.complete(
      AdherenceApiMapper.history(sampleHistoryJson()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits narrow viewport and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repository = _Repository();
    await tester.pumpWidget(_screen(repository));
    repository.pending.single.complete(
      AdherenceApiMapper.history(sampleHistoryJson()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
