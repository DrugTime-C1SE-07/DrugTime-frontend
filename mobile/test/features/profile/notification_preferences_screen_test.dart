import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/notification/notification_preferences.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/notification_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  late int refreshes;

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    store = _Store();
    remote = _Remote();
    refreshes = 0;
    controller =
        NotificationPreferencesController(store: store, familyAlerts: remote)
          ..onRemindersChanged = () => refreshes++;
    await controller.load();
    await t.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: NotificationPreferencesScope(
          controller: controller, child: const NotificationPreferencesScreen()),
    ));
    await t.pumpAndSettle();
  }

  bool on(WidgetTester t, String title) =>
      t.widget<Switch>(_switch(title)).value;

  testWidgets('đổi rung + nhắc lại rồi lưu: ghi máy và lập lại nhắc một lần',
      (t) async {
    await pump(t);
    expect(on(t, 'Bật nhắc nhở'), isTrue);
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
        const ReminderPreferences(vibrate: false, repeatIfMissed: true));
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

  testWidgets('mục chưa có tính năng nền vẫn khóa', (t) async {
    await pump(t);
    for (final title in [
      'Cảnh báo tương tác thuốc',
      'Sắp hết thuốc',
      'Nhắc lịch tái khám',
      'Cập nhật ứng dụng',
    ]) {
      expect(t.widget<Switch>(_switch(title)).onChanged, isNull, reason: title);
    }
  });
}
