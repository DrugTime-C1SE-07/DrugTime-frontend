class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isTransient = false});

  final String message;
  final int? statusCode;
  final bool isTransient;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$code: $message';
  }
}
