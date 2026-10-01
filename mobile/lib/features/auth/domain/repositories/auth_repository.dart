import '../entities/auth_session.dart';

/// Cổng dữ liệu xác thực người dùng. Bản hiện tại hỗ trợ InMemoryAuthRepository
/// để dựng UI và test, cùng RemoteAuthRepository kết nối Backend Identity API.
abstract interface class AuthRepository {
  /// Yêu cầu gửi mã OTP qua số điện thoại hoặc email.
  Future<void> requestOtp({String? phone, String? email});

  /// Xác thực mã OTP và nhận phiên đăng nhập [AuthSession].
  Future<AuthSession> verifyOtp({
    String? phone,
    String? email,
    required String token,
  });

  /// Lấy phiên đăng nhập hiện tại nếu có trong lưu trữ an toàn.
  Future<AuthSession?> getCurrentSession();

  /// Đăng xuất và huỷ phiên làm việc.
  Future<void> signOut();
}
