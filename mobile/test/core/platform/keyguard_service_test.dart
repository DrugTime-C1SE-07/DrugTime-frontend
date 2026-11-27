import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/platform/keyguard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> log;
  const channel = MethodChannel('vn.drugtime.drugtime_mobile/keyguard');

  setUp(() {
    log = <MethodCall>[];
  });

  group('DefaultKeyguardPlatform', () {
    test('isKeyguardLocked calls native channel and returns boolean', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'isKeyguardLocked') {
          return true;
        }
        return null;
      });

      const platform = DefaultKeyguardPlatform(channel);
      final isLocked = await platform.isKeyguardLocked();

      expect(isLocked, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'isKeyguardLocked');
    });

    test('isKeyguardLocked returns false on platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });

      const platform = DefaultKeyguardPlatform(channel);
      final isLocked = await platform.isKeyguardLocked();

      expect(isLocked, isFalse);
    });

    test('requestDismissKeyguard calls native channel and returns result',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'requestDismissKeyguard') {
          return true;
        }
        return false;
      });

      const platform = DefaultKeyguardPlatform(channel);
      final result = await platform.requestDismissKeyguard();

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'requestDismissKeyguard');
    });

    test('requestDismissKeyguard returns false on platform exception',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'ERROR');
      });

      const platform = DefaultKeyguardPlatform(channel);
      final result = await platform.requestDismissKeyguard();

      expect(result, isFalse);
    });
  });

  group('DefaultAppLeavePlatform', () {
    test('consumeUserLeftApp returns the native flag', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return false;
      });

      expect(await const DefaultAppLeavePlatform(channel).consumeUserLeftApp(),
          isFalse);
      expect(log.single.method, 'consumeUserLeftApp');
    });

    test('consumeUserLeftApp fails closed (locks) on platform errors',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });

      expect(await const DefaultAppLeavePlatform(channel).consumeUserLeftApp(),
          isTrue);
    });

    test('setRecentsPrivacy forwards the flag and never throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        throw PlatformException(code: 'UNAVAILABLE');
      });

      await const DefaultAppLeavePlatform(channel).setRecentsPrivacy(true);
      expect(log.single.method, 'setRecentsPrivacy');
      expect(log.single.arguments, isTrue);
    });
  });
}
