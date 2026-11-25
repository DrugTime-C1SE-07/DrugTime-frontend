import 'package:drugtime_mobile/core/security/device_authenticator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  _FakeLocalAuth({this.result = true, this.error, this.supported = true});

  final bool result;
  final Object? error;
  final bool supported;
  String? reason;
  bool? biometricOnly;

  @override
  Future<bool> isDeviceSupported() async {
    if (error != null) throw error!;
    return supported;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    reason = localizedReason;
    this.biometricOnly = biometricOnly;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  test('allows the device passcode and shows a Vietnamese reason', () async {
    final fake = _FakeLocalAuth();

    expect(await LocalDeviceAuthenticator(auth: fake).authenticate(), isTrue);
    expect(fake.biometricOnly, isFalse);
    expect(fake.reason, 'Xác thực để mở khóa DrugTime');
  });

  test('returns false when the user fails or cancels', () async {
    final auth = LocalDeviceAuthenticator(auth: _FakeLocalAuth(result: false));
    expect(await auth.authenticate(), isFalse);
  });

  for (final code in [
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.biometricLockout,
    LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthExceptionCode.userCanceled,
  ]) {
    test('maps ${code.name} to false instead of throwing', () async {
      final auth = LocalDeviceAuthenticator(
          auth: _FakeLocalAuth(error: LocalAuthException(code: code)));
      expect(await auth.authenticate(), isFalse);
    });
  }

  test('platform errors make the device count as unsupported', () async {
    final auth = LocalDeviceAuthenticator(
        auth: _FakeLocalAuth(error: PlatformException(code: 'x')));
    expect(await auth.isDeviceSupported(), isFalse);
    expect(await auth.authenticate(), isFalse);
  });

  test('reports device support from the platform', () async {
    final auth =
        LocalDeviceAuthenticator(auth: _FakeLocalAuth(supported: false));
    expect(await auth.isDeviceSupported(), isFalse);
  });
}
