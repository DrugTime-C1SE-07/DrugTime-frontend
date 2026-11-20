import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_controller.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_native.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_store.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/reminder_sound_screen.dart';

import 'profile_widget_helpers.dart';

const _pdf = PickedAudio(path: '/t', size: 900, head: [0x25, 0x50, 0x44, 0x46]);

CustomReminderSound _custom(int n) => CustomReminderSound(
      id: 'custom_$n',
      number: n,
      path: '/files/reminder_sounds/custom_$n.mp3',
      uri: 'content://media/external/audio/media/$n',
    );

void main() {
  late FakeReminderSoundStore store;
  late FakeReminderSoundNative native;
  late ReminderSoundController controller;

  Future<void> pumpScreen(WidgetTester t,
      {ReminderSoundSettings settings = const ReminderSoundSettings(),
      Size size = const Size(375, 812),
      double textScale = 1}) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    store = FakeReminderSoundStore(settings);
    controller = fakeReminderSoundController(store: store, native: native);
    await controller.load();
    await t.pumpWidget(ReminderSoundScope(
      controller: controller,
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: const ReminderSoundScreen(),
      ),
    ));
    await t.pumpAndSettle();
  }

  Finder addButton() =>
      find.widgetWithText(FilledButton, '+ Thêm âm thanh từ máy');

  Future<void> scrollTo(WidgetTester t, Finder finder) async {
    await t.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
  }

  setUp(() => native = FakeReminderSoundNative());

  testWidgets('tapping a sound selects it and keeps it on reopen__AC1',
      (t) async {
    await pumpScreen(t);
    expect(find.text('Âm thanh của bạn'), findsOneWidget);
    await t.tap(find.text('Nhẹ nhàng'));
    await t.pumpAndSettle();
    expect(store.settings.selectedId, 'gentle');

    await pumpScreen(t, settings: store.settings);
    final gentleRow =
        find.ancestor(of: find.text('Nhẹ nhàng'), matching: find.byType(Row));
    expect(
        find.descendant(
            of: gentleRow.first,
            matching: find.byIcon(Icons.radio_button_checked)),
        findsOneWidget);
  });

  testWidgets('preview A then B stops A; B again stops__AC2', (t) async {
    await pumpScreen(t);
    await t.tap(find.byKey(const ValueKey('preview-chime')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('preview-urgent')));
    await t.pump();
    expect(native.calls, ['play chime', 'stop', 'play urgent']);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('preview-urgent')));
    await t.pump();
    expect(native.calls.last, 'stop');
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    expect(find.byKey(const ValueKey('preview-silent')), findsNothing,
        reason: 'silent has nothing to preview');
  });

  testWidgets('invalid file shows its message and saves nothing__AC4',
      (t) async {
    await pumpScreen(t);
    native.picked = _pdf;
    await scrollTo(t, addButton());
    await t.tap(addButton());
    await t.pumpAndSettle();
    expect(find.text('Định dạng không hỗ trợ'), findsOneWidget);
    expect(store.writes, 0);
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(find.text('Định dạng không hỗ trợ'), findsNothing);
  });

  testWidgets('cancelling the picker shows nothing__AC15', (t) async {
    await pumpScreen(t);
    await scrollTo(t, addButton());
    await t.tap(addButton());
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(store.writes, 0);
  });

  testWidgets(
      'ten customs lock adding; deleting one after confirm unlocks__AC5 AC6',
      (t) async {
    await pumpScreen(t,
        settings: ReminderSoundSettings(
            selectedId: 'custom_3',
            customs: [for (var i = 1; i <= 10; i++) _custom(i)]));
    await scrollTo(t, addButton());
    expect(t.widget<FilledButton>(addButton()).onPressed, isNull);
    expect(find.text('Đã đủ 10 âm thanh. Xóa một âm thanh để thêm mới.'),
        findsOneWidget);

    final delete = find.byKey(const ValueKey('delete-custom_3'));
    await scrollTo(t, delete);
    await t.tap(delete);
    await t.pumpAndSettle();
    await t.tap(find.text('Hủy'));
    await t.pumpAndSettle();
    expect(store.settings.customs, hasLength(10));

    await t.tap(delete);
    await t.pumpAndSettle();
    await t.tap(find.text('Xóa'));
    await t.pumpAndSettle();
    expect(store.settings.customs, hasLength(9));
    expect(store.settings.selectedId, 'chime');
    await scrollTo(t, addButton());
    expect(t.widget<FilledButton>(addButton()).onPressed, isNotNull);
  });

  testWidgets('missing selected custom shows the fallback notice__AC7',
      (t) async {
    native.missing.add('/files/reminder_sounds/custom_1.mp3');
    await pumpScreen(t,
        settings: ReminderSoundSettings(
            selectedId: 'custom_1', customs: [_custom(1)]));
    expect(
        find.text('Âm thanh bạn chọn không còn, đã chuyển về chuông mặc định'),
        findsOneWidget);
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(store.settings.fallbackNotice, isFalse);
  });

  testWidgets('volume row opens system sound settings, no slider__AC11',
      (t) async {
    await pumpScreen(t);
    expect(find.byType(Slider), findsNothing);
    await t.tap(find.text('Âm lượng nhắc nhở'));
    await t.pump();
    expect(native.calls, ['openSoundSettings']);
  });

  testWidgets('leaving the screen stops the preview', (t) async {
    await pumpScreen(t);
    await t.tap(find.byKey(const ValueKey('preview-gentle')));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    expect(native.calls.last, 'stop');
    expect(controller.playingId, isNull);
  });

  testWidgets('iOS hides custom sounds and opens without errors__AC12',
      (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpScreen(t);
      expect(find.text('Âm thanh của bạn'), findsNothing);
      expect(addButton(), findsNothing);
      expect(find.text('Chọn và nghe thử âm thanh chưa khả dụng.'),
          findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(t.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android 9 shows built-in sounds without the custom group__AC12',
      (t) async {
    native.sdk = 28;
    await pumpScreen(t);
    expect(find.text('Chuông mặc định'), findsOneWidget);
    expect(find.text('Âm thanh của bạn'), findsNothing);
  });

  for (final width in [320.0, 375.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow at ${width.toInt()} px, text scale $scale',
          (t) async {
        native.missing.add('/files/reminder_sounds/custom_1.mp3');
        await pumpScreen(t,
            size: Size(width, 812),
            textScale: scale,
            settings: ReminderSoundSettings(
                selectedId: 'custom_1',
                customs: [for (var i = 1; i <= 10; i++) _custom(i)]));
        controller.togglePreview(ReminderSounds.chime);
        await t.pumpAndSettle();
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 20; i++) {
          await t.drag(scrollable, const Offset(0, -300));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        expect(addButton(), findsOneWidget);
      });
    }
  }
}
