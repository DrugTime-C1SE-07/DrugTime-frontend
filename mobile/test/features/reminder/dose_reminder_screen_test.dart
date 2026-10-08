import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/contracts/dose_outbox.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/features/reminder/domain/entities/dose_reminder.dart';
import 'package:drugtime_mobile/features/reminder/presentation/screens/dose_reminder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single screen renders required content and actions',
      (tester) async {
    final outbox = _FakeDoseOutbox();
    await _pumpReminder(tester,
        items: [_item(1, 'Losartan 50mg')], outbox: outbox);

    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Losartan 50mg'), findsOneWidget);
    expect(find.text('1 viên · Trước ăn tối'), findsOneWidget);
    expect(find.text('Đã uống'), findsOneWidget);
    expect(find.text('Nhắc lại sau 10 phút'), findsOneWidget);
    expect(find.text('Bỏ qua liều này'), findsOneWidget);
  });

  testWidgets('multiple screen expands and collapses all medicines',
      (tester) async {
    final items = [
      _item(1, 'Losartan 50mg'),
      _item(2, 'Metformin 500mg'),
      _item(3, 'Vitamin D3 1000IU'),
    ];
    await _pumpReminder(tester, items: items);

    expect(find.text('Losartan 50mg'), findsOneWidget);
    expect(find.text('Metformin 500mg'), findsNothing);
    expect(find.textContaining('3 thuốc cần uống'), findsOneWidget);

    await _tapVisible(tester, find.textContaining('Nhấn để xem tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Metformin 500mg'), findsOneWidget);
    expect(find.text('Vitamin D3 1000IU'), findsOneWidget);

    await _tapVisible(tester, find.text('Thu gọn').last);
    await tester.pumpAndSettle();
    expect(find.text('Metformin 500mg'), findsNothing);
  });

  testWidgets('confirm one medicine leaves sibling pending', (tester) async {
    final outbox = _FakeDoseOutbox();
    final items = [_item(1, 'Losartan'), _item(2, 'Metformin')];
    await _pumpReminder(tester, items: items, outbox: outbox);
    await _tapVisible(tester, find.textContaining('Nhấn để xem tất cả'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Xác nhận Losartan'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Losartan đã uống'), findsOneWidget);
    expect(find.byTooltip('Xác nhận Metformin'), findsOneWidget);
    expect(outbox.scheduleIds, [1]);
  });

  testWidgets(
      'partial group failure shows retry and does not duplicate success',
      (tester) async {
    final outbox = _FakeDoseOutbox(failOnceFor: {2});
    final items = [_item(1, 'Losartan'), _item(2, 'Metformin')];
    await _pumpReminder(tester, items: items, outbox: outbox);

    await tester.tap(find.text('Đã uống cả 2 thuốc'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Một số thuốc chưa được xác nhận'), findsOneWidget);

    await tester.tap(find.text('Đã uống cả 2 thuốc'));
    await tester.pumpAndSettle();
    expect(outbox.scheduleIds, [1, 2, 2]);
  });

  testWidgets('local error remains on screen and allows retry', (tester) async {
    final outbox = _FakeDoseOutbox(failOnceFor: {1});
    await _pumpReminder(tester, items: [_item(1, 'Losartan')], outbox: outbox);

    await tester.tap(find.text('Đã uống'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể lưu xác nhận'), findsOneWidget);
    expect(find.text('Losartan'), findsOneWidget);

    await tester.tap(find.text('Đã uống'));
    await tester.pumpAndSettle();
    expect(outbox.scheduleIds, [1, 1]);
  });

  testWidgets('single success remains visible and closes explicitly',
      (tester) async {
    final outbox = _FakeDoseOutbox();
    DoseReminderResult? result;
    await _pumpHost(
      tester,
      items: [_item(1, 'Losartan')],
      outbox: outbox,
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Đã uống'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Losartan đã uống'), findsOneWidget);
    expect(find.text('Đóng'), findsOneWidget);
    expect(result, isNull);
    expect(outbox.scheduleIds, [1]);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(result, DoseReminderResult.confirmed);
    expect(outbox.scheduleIds, [1]);
  });

  testWidgets('group success remains visible and prevents repeat enqueue',
      (tester) async {
    final outbox = _FakeDoseOutbox();
    final items = [_item(1, 'Losartan'), _item(2, 'Metformin')];
    await _pumpReminder(tester, items: items, outbox: outbox);

    await tester.tap(find.text('Đã uống cả 2 thuốc'));
    await tester.pumpAndSettle();

    expect(find.text('Đóng'), findsOneWidget);
    expect(outbox.scheduleIds, [1, 2]);
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Đã uống cả 2 thuốc'),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('snooze returns result and does not enqueue', (tester) async {
    final outbox = _FakeDoseOutbox();
    final scheduler = _FakeReminderScheduler();
    DoseReminderResult? result;
    await _pumpHost(
      tester,
      items: [_item(1, 'Losartan')],
      outbox: outbox,
      scheduler: scheduler,
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Nhắc lại sau 10 phút'));
    await tester.pumpAndSettle();

    expect(result, DoseReminderResult.snoozed);
    expect(outbox.scheduleIds, isEmpty);
    expect(scheduler.calls, hasLength(1));
    expect(scheduler.calls.single.remindAt, DateTime.utc(2026, 10, 7, 13, 15));
  });

  testWidgets('skip returns result without enqueue', (tester) async {
    final outbox = _FakeDoseOutbox();
    DoseReminderResult? result;
    await _pumpHost(
      tester,
      items: [_item(1, 'Losartan')],
      outbox: outbox,
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Bỏ qua liều này'));
    await tester.pumpAndSettle();

    expect(result, DoseReminderResult.skipped);
    expect(outbox.scheduleIds, isEmpty);
  });

  testWidgets('route with invalid arguments renders safe error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: onGenerateRoute,
        initialRoute: AppRoutes.doseReminder,
        onGenerateInitialRoutes: (name) => [
          onGenerateRoute(RouteSettings(name: name))!,
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể mở thông tin liều thuốc.'), findsOneWidget);
  });

  testWidgets('screen has no overflow at 1.5 text scale', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpReminder(
      tester,
      items: [
        _item(1, 'Losartan 50mg'),
        _item(2, 'Metformin 500mg'),
        _item(3, 'Vitamin D3 1000IU'),
      ],
    );
    await _tapVisible(tester, find.textContaining('Nhấn để xem tất cả'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Xem tất cả 3 thuốc'), findsNothing);
    expect(find.bySemanticsLabel('Thu gọn danh sách thuốc'), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpReminder(
  WidgetTester tester, {
  required List<DoseReminderItem> items,
  _FakeDoseOutbox? outbox,
  _FakeReminderScheduler? scheduler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: DoseReminderScreen(
        arguments: _arguments(
          items,
          outbox ?? _FakeDoseOutbox(),
          scheduler ?? _FakeReminderScheduler(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required List<DoseReminderItem> items,
  required _FakeDoseOutbox outbox,
  _FakeReminderScheduler? scheduler,
  required ValueChanged<DoseReminderResult?> onResult,
}) async {
  final args = _arguments(
    items,
    outbox,
    scheduler ?? _FakeReminderScheduler(),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result =
                    await Navigator.of(context).push<DoseReminderResult>(
                  MaterialPageRoute(
                    builder: (_) => DoseReminderScreen(arguments: args),
                  ),
                );
                onResult(result);
              },
              child: const Text('Mở nhắc thuốc'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở nhắc thuốc'));
  await tester.pumpAndSettle();
}

DoseReminderRouteArguments _arguments(
  List<DoseReminderItem> items,
  DoseOutbox outbox,
  ReminderScheduler scheduler,
) {
  return DoseReminderRouteArguments(
    group: DoseReminderGroup(items),
    outbox: outbox,
    scheduler: scheduler,
    clock: () => DateTime.utc(2026, 10, 7, 13, 5),
  );
}

DoseReminderItem _item(int id, String name) {
  return DoseReminderItem(
    medicationScheduleId: id,
    scheduledAt: DateTime.utc(2026, 9, 25, 13),
    medicationName: name,
    dosageText: '1 viên',
    instruction: 'Trước ăn tối',
  );
}

class _FakeDoseOutbox implements DoseOutbox {
  _FakeDoseOutbox({Set<int>? failOnceFor}) : _failOnceFor = failOnceFor ?? {};

  final Set<int> _failOnceFor;
  final List<int> scheduleIds = [];

  @override
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    scheduleIds.add(medicationScheduleId);
    if (_failOnceFor.remove(medicationScheduleId)) {
      throw StateError('write failed');
    }
    return LocalDoseLog(
      clientUuid: 'uuid-$medicationScheduleId',
      medicationScheduleId: medicationScheduleId,
      scheduledAt: scheduledAt,
      takenAt: takenAt,
      status: DoseLogStatus.taken,
      syncState: DoseLogSyncState.pendingUpload,
      localUpdatedAt: takenAt,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SnoozeCall {
  const _SnoozeCall(this.remindAt);
  final DateTime remindAt;
}

class _FakeReminderScheduler implements ReminderScheduler {
  final List<_SnoozeCall> calls = [];

  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {
    calls.add(_SnoozeCall(remindAt));
  }
}
