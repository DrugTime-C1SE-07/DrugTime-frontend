import 'dart:async';

import 'package:drugtime_mobile/core/platform/keyguard_service.dart';
import 'package:drugtime_mobile/core/security/device_authenticator.dart';

class FakeAuthenticator implements DeviceAuthenticator {
  FakeAuthenticator({this.result = true, this.supported = true});

  bool result;
  bool supported;
  int calls = 0;
  Completer<bool>? pending;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate() {
    calls++;
    return pending?.future ?? Future.value(result);
  }
}

class FakeLeavePlatform implements AppLeavePlatform {
  bool userLeft = true;
  bool? recentsPrivacy;
  int consumed = 0;

  @override
  Future<bool> consumeUserLeftApp() async {
    consumed++;
    return userLeft;
  }

  @override
  Future<void> setRecentsPrivacy(bool enabled) async =>
      recentsPrivacy = enabled;
}
