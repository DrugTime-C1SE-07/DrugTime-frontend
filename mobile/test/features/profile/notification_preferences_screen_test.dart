import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/notification/notification_preferences.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_controller.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_store.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/notification_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_widget_helpers.dart';

class _Store implements ReminderPreferencesStore {
  ReminderPreferences value = const ReminderPreferences();
  int writes = 0;
  @override
  Future<ReminderPreferences> read() async => value;
  @override
  Future<void> write(ReminderPreferences preferences) async {
    writes++;
    value = preferences;
  }

  @override
  Future<void> clear() async => value = const ReminderPreferences();
}

class _Remote implements FamilyAlertPreferenceRepository {
  bool value = true;
  bool fail = false;
  final writes = <bool>[];
  @override
  Future<bool> read() async => value;
  @override
  Future<void> write(bool enabled) async {
    if (fail) throw Exception('offline');
    writes.add(enabled);
    value = enabled;
  }
}

Finder _switch(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
    matching: find.byType(Switch));

Finder get _save => find.widgetWithText(FilledButton, 'Lưu thay đổi');

void main() {
  late _Store store;
  late _Remote remote;
  late NotificationPreferencesController controller;
  late ReminderSoundController soundController;
  late int refreshes;

  Future<void> pump(
    WidgetTester t, {
    ReminderSoundSettings soundSettings = const ReminderSoundSettings(),
    bool withFamilyRepo = true,
  }) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    store = _Store();
    remote = _Remote();
    refreshes = 0;
    soundController = fakeReminderSoundController(
      store: FakeReminderSoundStore(soundSettings),
    );
    await soundController.load();
    controller = NotificationPreferencesController(
      store: store,
      familyAlerts: withFamilyRepo ? remote : null,
    )..onRemindersChanged = () => refreshes++;
    await controller.load();
    await t.pumpWidget(ReminderSoundScope(
      controller: soundController,
      child: MaterialApp(
        theme: buildAppTheme(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.caregivers) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Màn Người giám sát')),
            );
          }
          return onGenerateRoute(settings);
        },
        home: NotificationPreferencesScope(
            controller: controller, child: const NotificationPreferencesScreen()),
      ),
    ));
    await t.pumpAndSettle();
  }

  bool on(WidgetTester t, String title) =>
      t.widget<Switch>(_switch(title)).value;

  testWidgets('đổi rung + nhắc lại rồi lưu: ghi máy và lập lại nhắc một lần',
      (t) async {
    await pump(t);
    expect(on(t, 'Bật nhắc nhở'), isTrue);
    expect(on(t, 'Nhắc lại nếu bỏ lỡ liều'), isTrue);
    expect(on(t, 'Báo người giám sát khi bỏ lỡ liều'), isTrue);
    expect(t.widget<FilledButton>(_save).onPressed, isNull,
        reason: 'chưa đổi gì thì không lưu');

    await t.tap(_switch('Rung khi nhắc nhở'));
    await t.tap(_switch('Nhắc lại nếu bỏ lỡ liều'));
    await t.pump();
    expect(store.writes, 0, reason: 'chỉ ghi khi bấm Lưu');
    await t.tap(_save);
    await t.pumpAndSettle();

    expect(store.value,
        const ReminderPreferences(vibrate: false, repeatIfMissed: false));
    expect(refreshes, 1);
    expect(remote.writes, isEmpty);
    expect(find.text('Đã lưu tùy chọn thông báo.'), findsOneWidget);
    expect(t.widget<FilledButton>(_save).onPressed, isNull);
  });

  testWidgets('tắt nhắc nhở: khóa rung/nhắc lại và báo nhắc đang tắt',
      (t) async {
    await pump(t);
    await t.tap(_switch('Bật nhắc nhở'));
    await t.pump();
    expect(t.widget<Switch>(_switch('Rung khi nhắc nhở')).onChanged, isNull);
    expect(
        t.widget<Switch>(_switch('Nhắc lại nếu bỏ lỡ liều')).onChanged, isNull);
    expect(find.textContaining('Nhắc uống thuốc đang tắt'), findsOneWidget);
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(store.value.enabled, isFalse);
    expect(refreshes, 1);
  });

  testWidgets('tắt báo người giám sát: gửi server, không lập lại nhắc',
      (t) async {
    await pump(t);
    await t.tap(_switch('Báo người giám sát khi bỏ lỡ liều'));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(remote.writes, [false]);
    expect(controller.familyAlertsEnabled, isFalse);
    expect(refreshes, 0);
  });

  testWidgets('server lỗi: báo lỗi, vẫn cho lưu lại', (t) async {
    await pump(t);
    remote.fail = true;
    await t.tap(_switch('Báo người giám sát khi bỏ lỡ liều'));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(find.textContaining('Chưa lưu được'), findsOneWidget);
    expect(controller.familyAlertsEnabled, isTrue);
    expect(t.widget<FilledButton>(_save).onPressed, isNotNull);
  });

  testWidgets('TC-606-24: Cảnh báo tương tác khóa bật, Sắp hết thuốc hoạt động, Nhắc tái khám/Cập nhật không có switch giả >= 14px',
      (t) async {
    await pump(t);
    expect(on(t, 'Cảnh báo tương tác thuốc'), isTrue);
    expect(t.widget<Switch>(_switch('Cảnh báo tương tác thuốc')).onChanged, isNull);
    expect(find.text('Luôn bật để bảo đảm an toàn dùng thuốc'), findsOneWidget);

    expect(on(t, 'Sắp hết thuốc'), isTrue);
    await t.tap(_switch('Sắp hết thuốc'));
    await t.pump();
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(store.value.toJson()['low_stock'], isFalse);

    for (final title in ['Nhắc lịch tái khám', 'Cập nhật ứng dụng']) {
      expect(_switch(title), findsNothing, reason: '$title must not show fake switch');
    }
    for (final label in t.widgetList<Text>(find.text('Chưa khả dụng'))) {
      expect(label.style?.fontSize, greaterThanOrEqualTo(14));
    }
  });

  testWidgets('TC-606-24b: hiện nhãn âm thật, giữ Switch người giám sát và dòng Quản lý người giám sát (Q1)',
      (t) async {
    await pump(t, soundSettings: const ReminderSoundSettings(selectedId: 'gentle'));
    expect(find.text('Nhẹ nhàng'), findsOneWidget);
    expect(find.text('Quản lý người giám sát'), findsOneWidget);
    await t.tap(find.text('Quản lý người giám sát'));
    await t.pumpAndSettle();
    expect(find.text('Màn Người giám sát'), findsOneWidget);
  });

  testWidgets('TC-606-25: quay lại khi còn nháp hỏi Bỏ các thay đổi?, Im lặng + tắt rung hiện CautionNote',
      (t) async {
    await pump(t, soundSettings: const ReminderSoundSettings(selectedId: 'silent'));
    await t.tap(_switch('Rung khi nhắc nhở'));
    await t.pump();
    expect(find.textContaining('không kêu và không rung'), findsOneWidget);

    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('Bỏ các thay đổi?'), findsOneWidget);
  });

  testWidgets('TC-606-24c: preview without server repo falls back to caregiver navigation row',
      (t) async {
    await pump(t, withFamilyRepo: false);
    expect(find.text('Quản lý tại Người giám sát'), findsOneWidget);
    await t.tap(find.text('Báo người giám sát khi bỏ lỡ liều'));
    await t.pumpAndSettle();
    expect(find.text('Màn Người giám sát'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(375, 812)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('TC-606-28 S08-4 no overflow at ${size.width.toInt()}x${size.height.toInt()} scale $scale',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        store = _Store();
        remote = _Remote();
        soundController = fakeReminderSoundController();
        await soundController.load();
        controller = NotificationPreferencesController(store: store, familyAlerts: remote);
        await controller.load();
        await t.pumpWidget(ReminderSoundScope(
          controller: soundController,
          child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: NotificationPreferencesScope(
              controller: controller,
              child: const NotificationPreferencesScreen(),
            ),
          ),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
}
