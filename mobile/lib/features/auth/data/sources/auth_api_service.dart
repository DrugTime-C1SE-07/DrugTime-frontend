import 'dart:convert';
import 'package:http/http.dart' as http;

/// Nguồn dữ liệu API từ xa cho tính năng xác thực (Auth Remote Data Source).
/// Tương thích trên cả Mobile (Android/iOS), Web và Desktop.
/// Kết nối trực tiếp với Backend FastAPI Identity Module:
/// - POST /auth/mobile/otp
/// - POST /auth/mobile/verify
class AuthApiService {
  final String baseUrl;
  final http.Client _client;

  AuthApiService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Gửi yêu cầu OTP qua số điện thoại (+84...) hoặc email.
  Future<void> requestMobileOtp({String? phone, String? email}) async {
    final uri = Uri.parse('$baseUrl/auth/mobile/otp');
    final payload = <String, dynamic>{
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      final errorMsg = _parseError(response.body);
      throw Exception(
        errorMsg ?? 'Không thể gửi mã OTP (${response.statusCode})',
      );
    }
  }

  /// Xác thực mã OTP và nhận token phiên làm việc.
  Future<Map<String, dynamic>> verifyMobileOtp({
    String? phone,
    String? email,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/mobile/verify');
    final payload = <String, dynamic>{
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'token': token,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final errorMsg = _parseError(response.body);
      throw Exception(
        errorMsg ?? 'Mã xác thực không hợp lệ (${response.statusCode})',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String? _parseError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return null;
  }
}
