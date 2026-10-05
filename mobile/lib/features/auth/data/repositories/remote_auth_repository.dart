import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../sources/auth_api_exception.dart';
import '../sources/auth_api_service.dart';
import '../sources/auth_session_store.dart';

/// Triển khai AuthRepository kết nối Backend REST API; phiên lưu qua [AuthSessionStore].
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required AuthApiService apiService,
    required AuthSessionStore sessionStore,
  })  : _api = apiService,
        _store = sessionStore;

  final AuthApiService _api;
  final AuthSessionStore _store;

  @override
  Future<void> requestOtp({String? phone, String? email}) =>
      _api.requestMobileOtp(phone: phone, email: email);

  @override
  Future<AuthSession> verifyOtp({
    String? phone,
    String? email,
    required String token,
  }) async {
    final response = await _api.verifyMobileOtp(phone: phone, email: email, token: token);
    final session = AuthSession.fromJson(response);
    await _store.write(session);
    return session;
  }

  @override
  Future<AuthSession> completeProfile({
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
  }) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw const AuthApiException(AuthErrorKind.invalidCredentials, statusCode: 401);
    }
    await _api.completeProfile(
      accessToken: session.accessToken,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
    final updated = session.copyWith(profileComplete: true);
    await _store.write(updated);
    return updated;
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    final session = await _store.read();
    if (session == null) return null;
    if (session.isExpired || session.accessToken.isEmpty) {
      await _store.clear();
      return null;
    }
    return session;
  }

  @override
  Future<void> signOut() => _store.clear();
}
