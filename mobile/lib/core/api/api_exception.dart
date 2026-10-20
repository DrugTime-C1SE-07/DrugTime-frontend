class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
    this.retryAfter,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  /// Giá trị header `Retry-After` (số giây) của phản hồi lỗi; `null` khi không có hoặc không
  /// phải số giây dương.
  final Duration? retryAfter;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$code: $message';
  }
}
