import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drugtime_mobile/core/notification/reminder_sound.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_controller.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_native.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_store.dart';

import '../../features/profile/profile_widget_helpers.dart';

const mp3Head = [0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
const mp3 =
    PickedAudio(path: '/cache/reminder_pick.tmp', size: 1048576, head: mp3Head);

CustomReminderSound custom(int n) => CustomReminderSound(
      id: 'custom_$n',
      number: n,
      path: '/files/reminder_sounds/custom_$n.mp3',
      uri: 'content://media/external/audio/media/$n',
    );

void main() {
  late FakeReminderSoundStore store;
  late FakeReminderSoundNative native;
  late FakeChannelPlatform channels;
  late ReminderSoundController controller;
  late int changes;

  Future<void> build(
      [ReminderSoundSettings settings = const ReminderSoundSettings(),
      TargetPlatform? platform]) async {
    store = FakeReminderSoundStore(settings);
    controller = fakeReminderSoundController(
        store: store,
        native: native,
        notifications: channels,
        targetPlatform: platform);
    changes = 0;
    controller.onSoundChanged = () => changes++;
    await controller.load();
  }

  setUp(() {
    native = FakeReminderSoundNative();
    channels = FakeChannelPlatform();
  });

  test('select saves, creates the channel and reschedules__AC1', () async {
    await build();
    await controller.select('gentle');
    expect(store.settings.selectedId, 'gentle');
    expect(controller.selected, ReminderSounds.gentle);
    expect(channels.created.last, 'drugtime_reminder_gentle_v1');
    expect(changes, 1);
  });

  test('selecting an unknown id changes nothing', () async {
    await build();
    await controller.select('nope');
    expect(store.settings.selectedId, 'chime');
    expect(changes, 0);
  });

  test('preview A then B stops A and plays B; B again stops__AC2', () async {
    await build();
    await controller.togglePreview(ReminderSounds.chime);
    await controller.togglePreview(ReminderSounds.urgent);
    expect(controller.playingId, 'urgent');
    expect(native.calls, ['play chime', 'stop', 'play urgent']);
    await controller.togglePreview(ReminderSounds.urgent);
    expect(controller.playingId, isNull);
    expect(native.calls.last, 'stop');
  });

  test('preview done from native clears the playing state__AC2', () async {
    await build();
    await controller.togglePreview(ReminderSounds.gentle);
    native.previewDone!();
    expect(controller.playingId, isNull);
  });

  test('preview failure shows the undecodable message', () async {
    native = _ThrowingPlayNative();
    await build();
    await controller.togglePreview(ReminderSounds.chime);
    expect(controller.playingId, isNull);
    expect(controller.error, 'Không phát được file này');
  });

  test('adding a valid file commits a neutral name and a channel__AC3 AC14',
      () async {
    await build(ReminderSoundSettings(customs: [custom(1), custom(3)]));
    native.picked = mp3;
    await controller.addFromDevice();
    final added = store.settings.customs.last;
    expect(added.number, 2, reason: 'smallest free number');
    expect(added.id, matches(RegExp(r'^custom_[0-9a-f]{16}$')));
    expect(added.sound.label, 'DrugTime nhắc nhở 2');
    expect(native.committed.single.ext, 'mp3');
    expect(added.path, isNot(contains('reminder_pick')));
    expect(channels.created.last, 'drugtime_reminder_${added.id}');
    expect(store.settings.selectedId, 'chime', reason: 'not auto-selected');
    expect(controller.error, isNull);
    expect(native.calls, isNot(contains('discard')));
  });

  group('invalid files are not saved__AC4', () {
    final cases = <String, (PickedAudio, int?)>{
      'Định dạng không hỗ trợ': (
        const PickedAudio(
            path: '/t', size: 900, head: [0x25, 0x50, 0x44, 0x46]),
        15000
      ),
      'File quá lớn (tối đa 10 MB)': (
        const PickedAudio(path: '/t', size: 10485761, head: mp3Head),
        15000
      ),
      'Âm thanh phải dài từ 1 giây đến 5 phút': (mp3, 300001),
      'Không phát được file này': (mp3, null),
    };
    cases.forEach((message, input) {
      test(message, () async {
        await build();
        native.picked = input.$1;
        native.durationMs = input.$2;
        await controller.addFromDevice();
        expect(controller.error, message);
        expect(store.writes, 0);
        expect(native.committed, isEmpty);
        expect(native.calls, contains('discard'));
      });
    });
  });

  test('commit failure shows a retry message and discards the temp file',
      () async {
    await build();
    native.picked = mp3;
    native.commitError = PlatformException(code: 'reminder_sound');
    await controller.addFromDevice();
    expect(controller.error, ReminderSoundController.addFailedMessage);
    expect(store.settings.customs, isEmpty);
    expect(native.calls, contains('discard'));
  });

  test('cancelling the picker changes nothing__AC15', () async {
    await build();
    await controller.addFromDevice();
    expect(native.calls, ['pick']);
    expect(controller.error, isNull);
    expect(store.writes, 0);
  });

  test('ten customs lock adding until one is deleted__AC5', () async {
    await build(ReminderSoundSettings(
        customs: [for (var i = 1; i <= 10; i++) custom(i)]));
    expect(controller.canAdd, isFalse);
    await controller.addFromDevice();
    expect(native.calls, isNot(contains('pick')));
    await controller.delete('custom_4');
    expect(controller.canAdd, isTrue);
  });

  test('deleting the selected custom falls back to chime and cleans up__AC6',
      () async {
    await build(
        ReminderSoundSettings(selectedId: 'custom_2', customs: [custom(2)]));
    await controller.delete('custom_2');
    expect(store.settings.selectedId, 'chime');
    expect(store.settings.customs, isEmpty);
    expect(channels.deleted, ['drugtime_reminder_custom_2']);
    expect(
        native.calls, contains('delete /files/reminder_sounds/custom_2.mp3'));
    expect(changes, 1);
  });

  test('deleting an unselected custom keeps the selection', () async {
    await build(ReminderSoundSettings(
        selectedId: 'urgent', customs: [custom(1), custom(2)]));
    await controller.delete('custom_1');
    expect(store.settings.selectedId, 'urgent');
    expect(changes, 0);
  });

  test('missing custom file falls back to chime with a notice__AC7 AC8',
      () async {
    native.missing.add('/files/reminder_sounds/custom_5.mp3');
    await build(
        ReminderSoundSettings(selectedId: 'custom_5', customs: [custom(5)]));
    expect(controller.selected, ReminderSounds.chime);
    expect(controller.selected, isNot(ReminderSounds.silent));
    expect(controller.fallbackNotice, isTrue);
    expect(store.settings.fallbackNotice, isTrue);
    expect(channels.created.last, 'drugtime_reminder_chime_v1');
    await controller.dismissFallbackNotice();
    expect(store.settings.fallbackNotice, isFalse);
  });

  test('unknown stored id falls back to chime, never silent__AC8', () async {
    await build(const ReminderSoundSettings(selectedId: 'deleted_long_ago'));
    expect(controller.selected, ReminderSounds.chime);
    expect(controller.fallbackNotice, isTrue);
  });

  test('silent and built-in selections are kept by ensureValid__AC7 AC8',
      () async {
    for (final id in ['silent', 'system', 'friendly']) {
      await build(ReminderSoundSettings(selectedId: id));
      await controller.ensureValid();
      expect(controller.selectedId, id);
      expect(controller.fallbackNotice, isFalse);
    }
  });

  test('ensureValid before load loads first', () async {
    store = FakeReminderSoundStore(
        const ReminderSoundSettings(selectedId: 'gentle'));
    controller = fakeReminderSoundController(
        store: store, native: native, notifications: channels);
    await controller.ensureValid();
    expect(controller.selectedId, 'gentle');
    expect(channels.created, ['drugtime_reminder_gentle_v1']);
  });

  test('clearAll removes every custom and resets to chime__Q1', () async {
    await build(ReminderSoundSettings(
        selectedId: 'custom_1', customs: [custom(1), custom(2)]));
    await controller.togglePreview(controller.customSounds.first);
    await controller.clearAll();
    expect(controller.selectedId, 'chime');
    expect(controller.customSounds, isEmpty);
    expect(controller.playingId, isNull);
    expect(channels.deleted,
        ['drugtime_reminder_custom_1', 'drugtime_reminder_custom_2']);
    expect(native.calls.where((c) => c.startsWith('delete')), hasLength(2));
  });

  test('custom sounds need Android 10+__AC12 Q2', () async {
    native.sdk = 28;
    await build();
    expect(controller.customSupported, isFalse);
    expect(controller.canAdd, isFalse);

    native.sdk = 29;
    await build();
    expect(controller.customSupported, isTrue);
  });

  test('iOS hides custom sounds and creates no Android channel__AC12',
      () async {
    await build(const ReminderSoundSettings(), TargetPlatform.iOS);
    expect(controller.customSupported, isFalse);
    await controller.select('gentle');
    expect(channels.created, isEmpty);
    expect(controller.selectedId, 'gentle');
  });

  test('openSoundSettings goes to native__AC11', () async {
    await build();
    await controller.openSoundSettings();
    expect(native.calls, ['openSoundSettings']);
  });
}

class _ThrowingPlayNative extends FakeReminderSoundNative {
  @override
  Future<void> play(ReminderSound sound) async =>
      throw PlatformException(code: 'play_failed');
}
