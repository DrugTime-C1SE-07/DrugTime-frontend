/// Đọc và chuẩn hóa mã liên kết của patient (QD-04, QD-34).
///
/// Mã có 10 ký tự trong bảng chữ hoa và số, bỏ `0 O 1 I L` (contract `LinkCode.code`).
/// Mã không bao giờ được ghi log; các hàm ở đây chỉ trả mã hoặc `null`.
library;

final _linkCodePattern = RegExp(r'^[A-HJKMNP-Z2-9]{10}$');

/// Đúng định dạng mã liên kết (đã chuẩn hóa).
bool isValidLinkCode(String code) => _linkCodePattern.hasMatch(code);

/// Chữ hoa, bỏ mọi khoảng trắng và gạch nối. Server chỉ bỏ khoảng trắng hai đầu và đổi chữ
/// hoa, nên phần còn lại phải làm ở app.
String normalizeLinkCodeInput(String raw) =>
    raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

/// Nội dung QR theo contract 3.10: đúng `drugtime://link?code=<mã>`. Mã phải khớp nguyên văn,
/// không chuẩn hóa: QR luôn do app sinh ra.
String? linkCodeFromQrPayload(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'drugtime' ||
      uri.host != 'link' ||
      uri.path.isNotEmpty ||
      uri.hasFragment) {
    return null;
  }
  return _validOrNull(uri.queryParameters['code']);
}

/// Link mời dạng web: `https://<host>/link#code=<mã>`. Chấp nhận thêm `?code=<mã>`, dạng mà
/// nút "Mở bằng ứng dụng" của trang `/link` dùng để chuyển sang app.
String? linkCodeFromInviteUri(Uri uri, {required String host}) {
  if (uri.scheme != 'https' ||
      uri.host.toLowerCase() != host.toLowerCase() ||
      uri.path != '/link') {
    return null;
  }
  final fromFragment = uri.hasFragment
      ? _tryQueryParameters(uri.fragment)['code']
      : null;
  return _validOrNull(fromFragment ?? uri.queryParameters['code']);
}

/// Link mời cố định ghép từ mã (QD-04): `https://<host>/link#code=<mã>`. Mã nằm sau `#` nên
/// không bị gửi lên server khi mở link.
String inviteLinkFor(String code, {required String host}) =>
    Uri(scheme: 'https', host: host, path: '/link', fragment: 'code=$code').toString();

/// Chuỗi người dùng gõ hoặc dán vào ô nhập: chuỗi QR, link mời, hoặc mã (có thể có khoảng
/// trắng, gạch nối, chữ thường). Trả mã hợp lệ hoặc `null`.
String? extractLinkCode(String input, {required String host}) {
  final trimmed = input.trim();
  if (trimmed.startsWith('drugtime:')) return linkCodeFromQrPayload(trimmed);
  if (trimmed.startsWith('https:') || trimmed.startsWith('http:')) {
    final uri = Uri.tryParse(trimmed);
    return uri == null ? null : linkCodeFromInviteUri(uri, host: host);
  }
  return _validOrNull(normalizeLinkCodeInput(trimmed));
}

String? _validOrNull(String? code) =>
    code != null && isValidLinkCode(code) ? code : null;

Map<String, String> _tryQueryParameters(String query) {
  try {
    return Uri.splitQueryString(query);
  } on FormatException {
    return const {};
  }
}
