import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Dữ liệu xác thực giả lập trong bộ nhớ, dùng cho test và dựng UI
/// mà không bắt buộc phải có backend đang chạy (tương đồng với InMemoryMedicationRepository).
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
      throw Exception('Mã xác thực không chính xác');
    }

    final session = AuthSession(
      userId: 'test-user-${phone ?? email ?? "anonymous"}',
      accessToken: 'mock-jwt-token-12345',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      profileComplete: true,
    );
    _currentSession = session;
    return session;
  }

  @override
  Future<AuthSession?> getCurrentSession() async => _currentSession;

  @override
  Future<void> signOut() async {
    _currentSession = null;
  }
}
