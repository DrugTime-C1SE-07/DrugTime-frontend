import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_exception.dart';

/// Nguồn dữ liệu API từ xa cho tính năng xác thực (Auth Remote Data Source).
/// Kết nối Backend FastAPI Identity Module theo api_contract:
/// - POST /auth/mobile/otp
/// - POST /auth/mobile/verify
/// - POST /auth/profile
class AuthApiService {
  AuthApiService({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  /// Địa chỉ Backend API, lấy từ `--dart-define=DRUGTIME_API_BASE_URL`.
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  /// Gửi yêu cầu OTP qua số điện thoại (+84...) hoặc email.
  Future<void> requestMobileOtp({String? phone, String? email}) async {
    await _post('/auth/mobile/otp', _identifier(phone: phone, email: email));
  }

  /// Xác thực mã OTP và nhận phiên làm việc.
  Future<Map<String, dynamic>> verifyMobileOtp({
    String? phone,
    String? email,
    required String token,
  }) async {
    final response = await _post(
      '/auth/mobile/verify',
      {..._identifier(phone: phone, email: email), 'token': token},
    );
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Lưu họ tên, ngày sinh, giới tính cho tài khoản đang đăng nhập.
  Future<void> completeProfile({
    required String accessToken,
    required String fullName,
    required DateTime dateOfBirth,
    required String gender,
  }) async {
    final dob = dateOfBirth.toIso8601String().substring(0, 10);
    await _post(
      '/auth/profile',
      {'ho_ten': fullName, 'ngay_sinh': dob, 'gioi_tinh': gender},
      accessToken: accessToken,
    );
  }

  Map<String, dynamic> _identifier({String? phone, String? email}) => {
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      };

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AuthApiException(AuthErrorKind.network);
    } on http.ClientException {
      throw const AuthApiException(AuthErrorKind.network);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw AuthApiException.fromStatus(response.statusCode, code: _errorCode(response));
  }

  /// `detail` dạng chuỗi (mã ổn định); null nếu không có hoặc là mảng lỗi theo field.
  String? _errorCode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
