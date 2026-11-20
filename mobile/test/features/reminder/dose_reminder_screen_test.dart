import 'dart:async';

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/contracts/dose_outbox.dart';
import 'package:drugtime_mobile/core/notification/reminder_scheduler.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/features/reminder/domain/entities/dose_reminder.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/chibi_pet.dart';
import 'package:drugtime_mobile/features/home/presentation/scene/living_banner.dart';
import 'package:drugtime_mobile/features/reminder/presentation/screens/dose_reminder_screen.dart';
import 'package:drugtime_mobile/features/reminder/presentation/widgets/reminder_mascot.dart';
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

  group('linh vật nhắc thuốc', () {
    testWidgets('nhắc theo lịch: hiện pet chibi và câu nhắc', (tester) async {
      await _pumpReminder(tester, items: [_item(1, 'Losartan 50mg')]);

      expect(find.byKey(const Key('dose-reminder-mascot')), findsOneWidget);
      expect(find.bySemanticsLabel('Linh vật nhắc bạn uống thuốc'),
          findsOneWidget);
      expect(find.text('Đến giờ rồi, uống thuốc thôi nào!'), findsOneWidget);
      expect(find.byKey(const Key('dose-reminder-garden')), findsNothing);
    });

    testWidgets('nhóm nhiều thuốc: câu nhắc nêu số thuốc', (tester) async {
      await _pumpReminder(tester,
          items: [_item(1, 'Losartan'), _item(2, 'Metformin')]);

      expect(find.text('Đến giờ rồi, có 2 thuốc đang chờ bạn!'), findsOneWidget);
    });

    testWidgets('uống xong: pet ăn mừng', (tester) async {
      await _pumpReminder(tester, items: [_item(1, 'Losartan')]);

      await tester.tap(find.text('Đã uống'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Linh vật vui mừng vì bạn đã uống thuốc'),
          findsOneWidget);
      expect(find.text('Giỏi quá! Hẹn bạn ở liều tiếp theo nhé.'),
          findsOneWidget);
    });

    testWidgets('lỗi ghi nhận: pet lo lắng, liều chưa đánh dấu đã uống',
        (tester) async {
      final outbox = _FakeDoseOutbox(failOnceFor: {1});
      await _pumpReminder(tester,
          items: [_item(1, 'Losartan')], outbox: outbox);

      await tester.tap(find.text('Đã uống'));
      await tester.pumpAndSettle();

      expect(
          find.bySemanticsLabel('Linh vật đang lo vì liều chưa được ghi nhận'),
          findsOneWidget);
      expect(find.byTooltip('Losartan đã uống'), findsNothing);
    });

    testWidgets('chạm vào pet không kích hoạt hành động nào', (tester) async {
      final outbox = _FakeDoseOutbox();
      await _pumpReminder(tester,
          items: [_item(1, 'Losartan')], outbox: outbox);

      await tester.tap(find.byKey(const Key('dose-reminder-mascot')));
      await tester.pumpAndSettle();

      expect(outbox.scheduleIds, isEmpty);
      expect(find.text('Đã uống'), findsOneWidget);
    });

    testWidgets('autoplay bật: pet chạy khung hình, giảm chuyển động thì dừng',
        (tester) async {
      LivingBanner.autoplay = true;
      addTearDown(() => LivingBanner.autoplay = false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReminderMascot(
            scheduledAt: DateTime.utc(2026, 9, 25, 13),
            now: DateTime.utc(2026, 9, 25, 13),
            confirmed: false,
            hasError: false,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('màn 320×568, chữ 1.3: không tràn bố cục', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpReminder(tester, items: [_item(1, 'Losartan 50mg')]);

      expect(tester.takeException(), isNull);
      expect(find.text('Đã uống'), findsOneWidget);
    });
  });

  group('reminderPetMood', () {
    PetMood mood({
      bool confirmed = false,
      bool hasError = false,
      bool still = false,
      double time = 0,
      double idle = 0,
      int hour = 20,
    }) =>
        reminderPetMood(
          confirmed: confirmed,
          hasError: hasError,
          still: still,
          time: time,
          idleSeconds: idle,
          hourVn: hour,
        );

    test('đã uống luôn ăn mừng, kể cả khi có lỗi cũ', () {
      expect(mood(confirmed: true, hasError: true), PetMood.celebrate);
    });

    test('có lỗi thì lo lắng', () {
      expect(mood(hasError: true, idle: 999), PetMood.concerned);
    });

    test('giảm chuyển động: đứng yên ôm trước ngực', () {
      expect(mood(still: true, idle: 999), PetMood.hold);
    });

    test('chu kỳ 6 giây: chỉ tay, ôm, rồi động tác theo buổi', () {
      expect(mood(time: 0.5), PetMood.point);
      expect(mood(time: 2.5), PetMood.hold);
      expect(mood(time: 4.5, hour: 20), PetMood.yawn);
      expect(mood(time: 6.5), PetMood.point);
    });

    test('động tác theo buổi: sáng vươn vai, trưa vẫy, chiều ngó trời, tối ngáp',
        () {
      expect(reminderDayPartMood(6), PetMood.stretch);
      expect(reminderDayPartMood(12), PetMood.wave);
      expect(reminderDayPartMood(16), PetMood.thinking);
      expect(reminderDayPartMood(21), PetMood.yawn);
      expect(reminderDayPartMood(3), PetMood.yawn);
    });

    test('sốt ruột sau 60 giây không thao tác', () {
      expect(mood(time: 1, idle: reminderMascotIdleBeforeStomp - .1),
          PetMood.point);
      expect(mood(time: 1, idle: reminderMascotIdleBeforeStomp),
          PetMood.stomp);
    });
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

  testWidgets('bấm "Đã uống": đợi pet ăn mừng xong rồi tự đóng',
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
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Linh vật vui mừng vì bạn đã uống thuốc'),
        findsOneWidget);

    // Chưa đóng giữa lúc ăn mừng.
    await tester.pump(
        ReminderMascot.celebrateStillHold - const Duration(milliseconds: 100));
    expect(result, isNull);
    expect(find.byType(DoseReminderScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(result, DoseReminderResult.confirmed);
    expect(find.byType(DoseReminderScreen), findsNothing);
    expect(outbox.scheduleIds, [1]);
  });

  testWidgets('nhóm: chỉ tự đóng khi đã uống đủ mọi thuốc', (tester) async {
    DoseReminderResult? result;
    await _pumpHost(
      tester,
      items: [_item(1, 'Losartan'), _item(2, 'Metformin')],
      outbox: _FakeDoseOutbox(),
      onResult: (value) => result = value,
    );
    await _tapVisible(tester, find.textContaining('Nhấn để xem tất cả'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Xác nhận Losartan'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(result, isNull);

    await tester.tap(find.byTooltip('Xác nhận Metformin'));
    await tester.pumpAndSettle();
    await tester.pump(ReminderMascot.celebrateStillHold);
    await tester.pumpAndSettle();
    expect(result, DoseReminderResult.confirmed);
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

  testWidgets('pending confirmation disables snooze and skip', (tester) async {
    final completer = Completer<LocalDoseLog>();
    final outbox = _FakeDoseOutbox(completer: completer);
    await _pumpReminder(tester, items: [_item(1, 'Losartan')], outbox: outbox);

    await tester.tap(find.text('Đã uống'));
    await tester.pump();

    final snooze = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Nhắc lại sau 10 phút'),
    );
    final skip = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Bỏ qua liều này'),
    );
    expect(snooze.onPressed, isNull);
    expect(skip.onPressed, isNull);

    completer.complete(_record(1));
    await tester.pumpAndSettle();
    expect(find.text('Đóng'), findsOneWidget);
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

  testWidgets('multiple screen shows stacked card with badge and expand prompt',
      (tester) async {
    final items = [
      _item(1, 'Losartan 50mg'),
      _item(2, 'Metformin 500mg'),
      _item(3, 'Vitamin D3 1000IU'),
    ];
    await _pumpReminder(tester, items: items);

    expect(find.text('+2 thuốc'), findsOneWidget);
    expect(find.textContaining('3 thuốc cần uống · Nhấn để xem tất cả'),
        findsOneWidget);
    expect(find.text('Đã uống cả 3 thuốc'), findsOneWidget);
  });

  testWidgets('expanded mode toggles selection and confirms only selected',
      (tester) async {
    final outbox = _FakeDoseOutbox();
    final items = [
      _item(1, 'Losartan 50mg'),
      _item(2, 'Metformin 500mg'),
      _item(3, 'Vitamin D3 1000IU'),
    ];
    await _pumpReminder(tester, items: items, outbox: outbox);

    await _tapVisible(tester, find.textContaining('Nhấn để xem tất cả'));
    await tester.pumpAndSettle();

    expect(find.text('Đã uống cả 3 thuốc'), findsOneWidget);

    // Unselect Metformin
    await tester.tap(find.text('Metformin 500mg'));
    await tester.pumpAndSettle();
    expect(find.text('Đã uống 2 thuốc'), findsOneWidget);

    // Unselect Vitamin D3
    await tester.tap(find.text('Vitamin D3 1000IU'));
    await tester.pumpAndSettle();
    expect(find.text('Đã uống 1 thuốc'), findsOneWidget);

    // Confirm the remaining 1 selected medicine (Losartan)
    await tester.tap(find.text('Đã uống 1 thuốc'));
    await tester.pumpAndSettle();

    expect(outbox.scheduleIds, [1]);
  });

  group('P1 · lời nhắc từ người thân (sender)', () {
    Future<void> pumpCaregiver(
        WidgetTester tester, _FakeDoseOutbox outbox) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: DoseReminderScreen(
          arguments: DoseReminderRouteArguments(
            group: DoseReminderGroup([_item(1, 'Losartan 50mg')]),
            outbox: outbox,
            scheduler: _FakeReminderScheduler(),
            clock: () => DateTime.utc(2026, 9, 25, 15, 15),
            sender: 'Con Nam',
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'tiêu đề người nhắc, giờ hiện tại, cảnh hai linh vật, không hoãn (AC10)',
        (tester) async {
      await pumpCaregiver(tester, _FakeDoseOutbox());
      expect(find.text('DrugTime · Con Nam nhắc bạn'), findsOneWidget);
      expect(find.text('22:15'), findsOneWidget);
      expect(find.text('Bạn chưa uống liều 20:00'), findsOneWidget);
      expect(
          find.textContaining('không phải hướng dẫn uống bù'), findsOneWidget);
      expect(find.byKey(const Key('dose-reminder-garden')), findsOneWidget);
      expect(find.text('Nhắc lại sau 10 phút'), findsNothing);
      expect(find.text('Đã uống'), findsOneWidget);
      expect(find.text('Bỏ qua liều này'), findsOneWidget);
      expect(find.textContaining('Gọi'), findsNothing);
    });

    testWidgets('bấm "Đã uống" hai lần nhanh: chỉ ghi một lần (AC12)',
        (tester) async {
      final pending = Completer<LocalDoseLog>();
      final outbox = _FakeDoseOutbox(completer: pending);
      await pumpCaregiver(tester, outbox);
      await tester.tap(find.text('Đã uống'));
      await tester.pump();
      await tester.tap(find.text('Đã uống'), warnIfMissed: false);
      await tester.pump();
      pending.complete(_record(1,
          scheduledAt: DateTime.utc(2026, 9, 25, 13),
          takenAt: DateTime.utc(2026, 9, 25, 15, 15)));
      await tester.pumpAndSettle();
      expect(outbox.scheduleIds, [1]);
      expect(find.text('Đã ghi nhận liều 20:00'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
    });
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
  _FakeDoseOutbox({Set<int>? failOnceFor, this.completer})
      : _failOnceFor = failOnceFor ?? {};

  final Set<int> _failOnceFor;
  final Completer<LocalDoseLog>? completer;
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
    if (completer case final pending?) return pending.future;
    return _record(medicationScheduleId,
        scheduledAt: scheduledAt, takenAt: takenAt);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LocalDoseLog _record(
  int medicationScheduleId, {
  DateTime? scheduledAt,
  DateTime? takenAt,
}) {
  final persistedAt = takenAt ?? DateTime.utc(2026, 10, 7, 13, 5);
  return LocalDoseLog(
    clientUuid: 'uuid-$medicationScheduleId',
    medicationScheduleId: medicationScheduleId,
    scheduledAt: scheduledAt ?? DateTime.utc(2026, 9, 25, 13),
    takenAt: persistedAt,
    status: DoseLogStatus.taken,
    syncState: DoseLogSyncState.pendingUpload,
    localUpdatedAt: persistedAt,
  );
}

class _SnoozeCall {
  const _SnoozeCall(this.remindAt);
  final DateTime remindAt;
}

class _FakeReminderScheduler implements ReminderScheduler {
  final List<_SnoozeCall> calls = [];
  final List<Map<String, dynamic>> cancelledOccurrences = [];
  final List<int> cancelledSchedules = [];

  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {
    calls.add(_SnoozeCall(remindAt));
  }

  @override
  Future<void> cancelOccurrence({
    int? scheduleId,
    int? medicationScheduleId,
    required DateTime scheduledAt,
  }) async {
    cancelledOccurrences.add({
      'scheduleId': scheduleId ?? medicationScheduleId,
      'scheduledAt': scheduledAt,
    });
  }

  @override
  Future<void> cancelAllForSchedule(int scheduleId) async {
    cancelledSchedules.add(scheduleId);
  }
}
