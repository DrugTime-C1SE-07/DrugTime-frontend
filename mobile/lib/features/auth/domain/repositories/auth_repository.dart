import '../entities/auth_session.dart';

/// Cổng dữ liệu xác thực người dùng. App chạy thật dùng RemoteAuthRepository (Backend Identity API);
/// InMemoryAuthRepository chỉ dùng trong test.
abstract interface class AuthRepository {
  /// Yêu cầu gửi mã OTP qua số điện thoại hoặc email.
  Future<void> requestOtp({String? phone, String? email});

  /// Xác thực mã OTP, lưu và trả về phiên đăng nhập [AuthSession].
  Future<AuthSession> verifyOtp({
    String? phone,
    String? email,
    required String token,
  });

  /// Lưu hồ sơ cơ bản cho tài khoản đang đăng nhập; trả về phiên đã cập nhật `profileComplete`.
  Future<AuthSession> completeProfile({
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
  });

  /// Phiên đang lưu nếu còn hạn; phiên hết hạn bị xóa và trả về null.
  Future<AuthSession?> getCurrentSession();

  /// Đăng xuất và xóa phiên đã lưu.
  Future<void> signOut();
}
