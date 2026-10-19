enum FamilyLinkCodeFailureKind {
  network,
  unauthorized,
  forbidden,
  unavailable,
  invalidResponse,
}

/// Lỗi an toàn để hiển thị: không giữ body hay thông điệp gốc từ máy chủ.
class FamilyLinkCodeFailure implements Exception {
  const FamilyLinkCodeFailure(this.kind);

  final FamilyLinkCodeFailureKind kind;
}
