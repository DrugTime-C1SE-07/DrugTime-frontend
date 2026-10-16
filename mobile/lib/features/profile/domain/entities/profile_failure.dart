enum ProfileFailureKind {
  network,
  unauthorized,
  forbidden,
  consent,
  duplicate,
  missing,
  validation,
  unavailable,
  unsupported,
  invalidResponse
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.kind);
  final ProfileFailureKind kind;
  bool get removesAccess => {
        ProfileFailureKind.unauthorized,
        ProfileFailureKind.forbidden,
        ProfileFailureKind.consent
      }.contains(kind);
  String get message => switch (kind) {
        ProfileFailureKind.network => 'Không thể kết nối. Vui lòng thử lại.',
        ProfileFailureKind.unauthorized =>
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        ProfileFailureKind.forbidden =>
          'Bạn không có quyền truy cập hồ sơ này.',
        ProfileFailureKind.consent =>
          'Cần đồng ý xử lý dữ liệu sức khỏe để tiếp tục.',
        ProfileFailureKind.duplicate => 'Bệnh này đã có trong hồ sơ của bạn.',
        ProfileFailureKind.missing =>
          'Thông tin bệnh không còn tồn tại. Vui lòng tải lại.',
        ProfileFailureKind.validation =>
          'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
        ProfileFailureKind.unavailable =>
          'Chưa thể xử lý hồ sơ lúc này. Vui lòng thử lại.',
        ProfileFailureKind.unsupported =>
          'Hồ sơ cần kết nối Backend API trên ứng dụng di động.',
        ProfileFailureKind.invalidResponse =>
          'Dữ liệu hồ sơ trả về chưa hợp lệ. Vui lòng thử lại.',
      };
  // Do not include API response bodies or health data in exception diagnostics.
  @override
  String toString() => 'ProfileFailure(${kind.name})';
}
