/// Thực thể phiên đăng nhập và thông tin xác thực người dùng.
library;

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    this.tokenType = 'bearer',
    this.sessionType = 'mobile',
    required this.expiresAt,
    this.expiresInSeconds = 0,
    this.profileComplete = false,
  });

  final String userId;
  final String accessToken;
  final String tokenType;
  final String sessionType;
  final DateTime expiresAt;
  final int expiresInSeconds;
  final bool profileComplete;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AuthSession copyWith({bool? profileComplete}) => AuthSession(
        userId: userId,
        accessToken: accessToken,
        tokenType: tokenType,
        sessionType: sessionType,
        expiresAt: expiresAt,
        expiresInSeconds: expiresInSeconds,
        profileComplete: profileComplete ?? this.profileComplete,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'access_token': accessToken,
        'token_type': tokenType,
        'session_type': sessionType,
        'expires_at': expiresAt.toIso8601String(),
        'expires_in': expiresInSeconds,
        'profile_complete': profileComplete,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final sessionMap = json['session'] as Map<String, dynamic>? ?? json;
    return AuthSession(
      userId: json['user_id']?.toString() ?? '',
      accessToken: sessionMap['access_token']?.toString() ?? '',
      tokenType: sessionMap['token_type']?.toString() ?? 'bearer',
      sessionType: sessionMap['session_type']?.toString() ?? 'mobile',
      expiresAt: sessionMap['expires_at'] != null
          ? DateTime.tryParse(sessionMap['expires_at'].toString()) ??
              DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      expiresInSeconds: (sessionMap['expires_in'] as num?)?.toInt() ?? 0,
      profileComplete: json['profile_complete'] as bool? ?? false,
    );
  }
}
