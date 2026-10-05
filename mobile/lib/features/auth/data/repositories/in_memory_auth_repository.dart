import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../sources/auth_api_exception.dart';

/// Dữ liệu xác thực giả lập trong bộ nhớ, CHỈ dùng cho test (app chạy thật dùng RemoteAuthRepository).
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({
    AuthSession? initialSession,
    this.simulatedDelay = const Duration(milliseconds: 100),
    this.shouldFail = false,
    this.failureMessage = 'Lỗi giả lập xác thực',
  }) : _currentSession = initialSession;

  AuthSession? _currentSession;
  final Duration simulatedDelay;
  final bool shouldFail;
  final String failureMessage;

  final List<String> requestedPhoneOtps = [];
  final List<String> requestedEmailOtps = [];

  @override
  Future<void> requestOtp({String? phone, String? email}) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (shouldFail) {
      throw Exception(failureMessage);
    }

    if (phone != null && phone.isNotEmpty) {
      requestedPhoneOtps.add(phone);
    }
    if (email != null && email.isNotEmpty) {
      requestedEmailOtps.add(email);
    }
  }

  @override
  Future<AuthSession> verifyOtp({
    String? phone,
    String? email,
    required String token,
  }) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (shouldFail) {
      throw Exception(failureMessage);
    }

    if (token == '000000') {
      throw const AuthApiException(AuthErrorKind.invalidCredentials, statusCode: 401);
    }

    final session = AuthSession(
      userId: 'test-user-${phone ?? email ?? "anonymous"}',
      accessToken: 'mock-jwt-token-12345',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      profileComplete: verifiedProfileComplete,
    );
    _currentSession = session;
    return session;
  }

  /// Cờ `profileComplete` trả về sau khi verify (mô phỏng người mới / người cũ).
  bool verifiedProfileComplete = true;

  final List<(String, DateTime, String)> completedProfiles = [];

  @override
  Future<AuthSession> completeProfile({
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
  }) async {
    if (shouldFail) {
      throw Exception(failureMessage);
    }
    final session = _currentSession;
    if (session == null) {
      throw StateError('Chưa đăng nhập');
    }
    completedProfiles.add((fullName, dateOfBirth, gender));
    return _currentSession = session.copyWith(profileComplete: true);
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    final session = _currentSession;
    if (session != null && session.isExpired) {
      return _currentSession = null;
    }
    return session;
  }

  @override
  Future<void> signOut() async {
    _currentSession = null;
  }
}
