import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../sources/auth_api_service.dart';

/// Triển khai AuthRepository kết nối qua Backend REST API.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    AuthApiService? apiService,
  }) : _apiService = apiService ?? AuthApiService();

  final AuthApiService _apiService;
  AuthSession? _cachedSession;

  @override
  Future<void> requestOtp({String? phone, String? email}) async {
    await _apiService.requestMobileOtp(phone: phone, email: email);
  }

  @override
  Future<AuthSession> verifyOtp({
    String? phone,
    String? email,
    required String token,
  }) async {
    final response = await _apiService.verifyMobileOtp(
      phone: phone,
      email: email,
      token: token,
    );
    final session = AuthSession.fromJson(response);
    _cachedSession = session;
    return session;
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    return _cachedSession;
  }

  @override
  Future<void> signOut() async {
    _cachedSession = null;
  }
}
