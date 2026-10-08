import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_api_exception.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/login_method.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository ném lỗi API chỉ định ở mọi thao tác.
class _FailingRepository extends InMemoryAuthRepository {
  _FailingRepository(this.error, {super.initialSession})
      : super(simulatedDelay: Duration.zero);

  final Object error;

  @override
  Future<void> requestOtp({String? phone, String? email}) async => throw error;

  @override
  Future<AuthSession> verifyOtp({String? phone, String? email, required String token}) async =>
      throw error;

  @override
  Future<AuthSession> completeProfile({
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
  }) async =>
      throw error;
}

AuthSession _session({bool profileComplete = false}) => AuthSession(
      userId: 'u-1',
      accessToken: 'app-token',
      expiresAt: DateTime.now().add(const Duration(days: 10)),
      profileComplete: profileComplete,
    );

void main() {
  group('thông điệp lỗi theo mã', () {
    final cases = <(AuthApiException, String)>[
      (const AuthApiException(AuthErrorKind.invalidCredentials), 'Mã OTP không đúng hoặc đã hết hạn'),
      (
        const AuthApiException(AuthErrorKind.adminMustUseWeb, code: 'admin_must_use_web'),
        'Tài khoản quản trị vui lòng đăng nhập trên trang quản trị'
      ),
      (
        const AuthApiException(AuthErrorKind.invalidInput, code: 'invalid_phone'),
        'Số điện thoại không hợp lệ'
      ),
      (
        const AuthApiException(AuthErrorKind.invalidInput),
        'Thông tin chưa hợp lệ, vui lòng kiểm tra lại'
      ),
      (
        const AuthApiException(AuthErrorKind.rateLimited, code: 'rate_limited'),
        'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút'
      ),
      (
        const AuthApiException(AuthErrorKind.unavailable, code: 'auth_provider_unavailable'),
        'Hệ thống đang bận, vui lòng thử lại sau'
      ),
      (
        const AuthApiException(AuthErrorKind.network),
        'Không kết nối được máy chủ, vui lòng kiểm tra mạng'
      ),
    ];
    for (final (error, message) in cases) {
      test('verify ${error.kind} ${error.code ?? ''} → "$message"', () async {
        final controller = AuthController(_FailingRepository(error))..setMethod(LoginMethod.email);

        expect(await controller.verifyOtp(token: '123456'), isFalse);
        expect(controller.errorMessage, message);
        expect(controller.isAuthenticated, isFalse);
      });
    }

    test('request OTP 429 → thông điệp thử lại sau', () async {
      final controller = AuthController(
          _FailingRepository(const AuthApiException(AuthErrorKind.rateLimited)))
        ..setMethod(LoginMethod.email);

      expect(await controller.requestOtp('lan@example.com'), isFalse);
      expect(controller.errorMessage, 'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút');
    });

    test('lỗi không phải AuthApiException không lộ nội dung', () async {
      final controller = AuthController(_FailingRepository(Exception('stack trace secret')))
        ..setMethod(LoginMethod.email);

      await controller.verifyOtp(token: '123456');

      expect(controller.errorMessage, 'Đã có lỗi xảy ra, vui lòng thử lại');
    });
  });

  group('completeProfile', () {
    late InMemoryAuthRepository repo;
    late AuthController controller;

    setUp(() async {
      repo = InMemoryAuthRepository(initialSession: _session(), simulatedDelay: Duration.zero);
      controller = AuthController(repo);
      await controller.initSession();
    });

    test('người mới: needsProfile = true', () {
      expect(controller.isAuthenticated, isTrue);
      expect(controller.needsProfile, isTrue);
    });

    final invalid = <(String, String, DateTime?, String?, String)>[
      ('họ tên rỗng', '   ', DateTime(1958, 4, 12), 'nu', 'Vui lòng nhập họ tên'),
      ('thiếu ngày sinh', 'Lan', null, 'nu', 'Vui lòng chọn ngày sinh'),
      (
        'ngày sinh tương lai',
        'Lan',
        DateTime.now().add(const Duration(days: 1)),
        'nu',
        'Ngày sinh không được sau hôm nay'
      ),
      ('thiếu giới tính', 'Lan', DateTime(1958, 4, 12), null, 'Vui lòng chọn giới tính'),
      ('giới tính lạ', 'Lan', DateTime(1958, 4, 12), 'female', 'Vui lòng chọn giới tính'),
    ];
    for (final (name, fullName, dob, gender, message) in invalid) {
      test('$name → báo lỗi tại chỗ, không gọi repo', () async {
        final ok = await controller.completeProfile(
            fullName: fullName, dateOfBirth: dob, gender: gender);

        expect(ok, isFalse);
        expect(controller.errorMessage, message);
        expect(repo.completedProfiles, isEmpty);
      });
    }

    test('hợp lệ → gọi repo với họ tên đã trim, needsProfile = false', () async {
      final ok = await controller.completeProfile(
          fullName: '  Nguyễn Thị Lan ', dateOfBirth: DateTime(1958, 4, 12), gender: 'nu');

      expect(ok, isTrue);
      expect(repo.completedProfiles.single.$1, 'Nguyễn Thị Lan');
      expect(controller.needsProfile, isFalse);
    });

    test('API trả 401 → xóa phiên, báo hết phiên', () async {
      final failing = _FailingRepository(
          const AuthApiException(AuthErrorKind.invalidCredentials),
          initialSession: _session());
      final c = AuthController(failing);
      await c.initSession();

      final ok =
          await c.completeProfile(fullName: 'Lan', dateOfBirth: DateTime(1958), gender: 'nu');

      expect(ok, isFalse);
      expect(c.isAuthenticated, isFalse);
      expect(c.errorMessage, 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
    });
  });

  test('handleUnauthorized xóa phiên và báo listener', () async {
    final repo = InMemoryAuthRepository(
        initialSession: _session(profileComplete: true), simulatedDelay: Duration.zero);
    final controller = AuthController(repo);
    await controller.initSession();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.handleUnauthorized();

    expect(controller.isAuthenticated, isFalse);
    expect(await repo.getCurrentSession(), isNull);
    expect(notified, greaterThan(0));
  });

  group('termsAccepted', () {
    Future<AuthController> signedIn() async {
      final controller = AuthController(InMemoryAuthRepository(
          initialSession: _session(profileComplete: true), simulatedDelay: Duration.zero));
      await controller.initSession();
      return controller;
    }

    test('mặc định false; setTermsAccepted đổi giá trị và báo listener', () {
      final controller = AuthController(InMemoryAuthRepository(simulatedDelay: Duration.zero));
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.termsAccepted, isFalse);
      controller.setTermsAccepted(true);
      controller.setTermsAccepted(true);

      expect(controller.termsAccepted, isTrue);
      expect(notified, 1);
    });

    test('signOut đặt lại false', () async {
      final controller = await signedIn();
      controller.setTermsAccepted(true);

      await controller.signOut();

      expect(controller.termsAccepted, isFalse);
    });

    test('handleUnauthorized (401) đặt lại false', () async {
      final controller = await signedIn();
      controller.setTermsAccepted(true);

      await controller.handleUnauthorized();

      expect(controller.termsAccepted, isFalse);
    });
  });
}
