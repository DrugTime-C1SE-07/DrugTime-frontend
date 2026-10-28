import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/notification/family_push_service.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_alert.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('optional Firebase configuration', () {
    const channelPrefix =
        'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi';
    const codec = StandardMessageCodec();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMessageHandler(
        '$channelPrefix.initializeCore',
        (_) async => codec.encodeMessage([[]]),
      );
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMessageHandler('$channelPrefix.initializeCore', null);
      messenger.setMockMessageHandler(
          '$channelPrefix.optionsFromResource', null);
    });

    test('missing native configuration disables push without failing startup',
        () async {
      messenger.setMockMessageHandler(
        '$channelPrefix.optionsFromResource',
        (_) async => codec.encodeMessage([
          'java.lang.Exception',
          'Failed to load FirebaseOptions from resource. '
              'Check that you have defined values.xml correctly.',
          null,
        ]),
      );

      final enabled = await initializeFamilyFirebase();
      expect(enabled, isFalse);
      final push = FamilyPushService(
        android: enabled,
        showForeground: (_, __) async => fail('Push is disabled'),
      );
      await push.start();
      await push.receive({'notification_id': '1'}, foreground: true);
      expect(push.hasPending, isFalse);
      push.dispose();
    });

    test('unrelated initialization errors are reported', () async {
      messenger.setMockMessageHandler(
        '$channelPrefix.optionsFromResource',
        (_) async => codec.encodeMessage([
          'channel-error',
          'Native initialization failed',
          null,
        ]),
      );

      await expectLater(
        initializeFamilyFirebase(),
        throwsA(isA<PlatformException>()
            .having((error) => error.code, 'code', 'channel-error')),
      );
    });
  });

  test('positive int64 boundary and malformed payload', () {
    expect(familyNotificationId('1'), 1);
    expect(familyNotificationId('9223372036854775807'), 9223372036854775807);
    for (final value in [
      null,
      1,
      '0',
      '-1',
      '1.0',
      '9223372036854775808',
      '1e3',
      ' 1',
      '{}'
    ]) {
      expect(familyNotificationId(value), isNull);
    }
  });
  test('foreground only displays valid ID; stale callback ignored after logout',
      () async {
    final shown = <int>[];
    final push = FamilyPushService(
        android: true,
        showForeground: (id, _) async {
          shown.add(id);
        });
    await push.receive({'notification_id': '7', 'patient_id': 'untrusted'},
        foreground: true);
    expect(shown, [7]);
    expect(push.pendingId, isNull);
    push.offer('7');
    expect(push.pendingId, 7);
    push.clear();
    push.offer('8');
    expect(push.hasPending, false);
    push.allow();
    push.offer('invalid');
    expect(push.invalid, true);
    push.dispose();
  });
  test('sync_request ignored by family flow (foreground) and triggers sync',
      () async {
    final shown = <int>[];
    var syncs = 0;
    final push = FamilyPushService(
      android: true,
      showForeground: (id, _) async => shown.add(id),
      onSyncRequest: () async => syncs++,
    );
    var notified = 0;
    push.addListener(() => notified++);

    await push.receive({'type': 'sync_request'}, foreground: true);

    expect(syncs, 1);
    expect(shown, isEmpty);
    expect(push.hasPending, isFalse);
    expect(push.invalid, isFalse);
    expect(notified, 0);

    // Hết phiên: không đồng bộ theo push cũ.
    push.clear();
    await push.receive({'type': 'sync_request'}, foreground: true);
    expect(syncs, 1);
    push.dispose();
  });
  test('family push unchanged when onSyncRequest is set', () async {
    final shown = <int>[];
    var syncs = 0;
    final push = FamilyPushService(
      android: true,
      showForeground: (id, _) async => shown.add(id),
      onSyncRequest: () async => syncs++,
    );

    await push.receive({'notification_id': '9'}, foreground: true);
    await push.receive({}, foreground: true);

    expect(shown, [9]);
    expect(syncs, 0);
    expect(push.invalid, isTrue);
    push.dispose();
  });
  test('isSyncRequest only matches the data type', () {
    expect(isSyncRequest({'type': 'sync_request'}), isTrue);
    expect(isSyncRequest({'notification_id': '1'}), isFalse);
    expect(isSyncRequest({'type': 'other'}), isFalse);
  });
  test('iOS does not touch Firebase or foreground Android path', () async {
    final push = FamilyPushService(
        android: false,
        showForeground: (_, __) async => fail('Android callback'));
    await push.start();
    await push.receive({'notification_id': '1'}, foreground: true);
    expect(push.hasPending, false);
    push.dispose();
  });
}
