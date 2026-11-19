import 'package:flutter/services.dart';

import '../../domain/entities/link_code.dart';

/// `K7M2Q9XAR4` → `K7M2 Q9XA R4` (nhóm 4-4-2) để dễ đọc và so với màn của người thân.
String groupLinkCode(String code) {
  final groups = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    groups.add(code.substring(i, i + 4 > code.length ? code.length : i + 4));
  }
  return groups.join(' ');
}

/// Chuẩn hóa ô nhập mã khi gõ hoặc dán: chữ hoa, bỏ khoảng trắng và gạch nối, tối đa 10 ký tự,
/// hiển thị theo nhóm. Dán chuỗi QR hay link mời thì tách lấy mã; chuỗi có `://` mà không đọc
/// được mã thì giữ nguyên nội dung cũ.
class LinkCodeInputFormatter extends TextInputFormatter {
  LinkCodeInputFormatter({required this.inviteLinkHost});

  final String inviteLinkHost;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String normalized;
    if (newValue.text.contains('://')) {
      final code = extractLinkCode(newValue.text, host: inviteLinkHost);
      if (code == null) return oldValue;
      normalized = code;
    } else {
      final raw = normalizeLinkCodeInput(newValue.text);
      normalized = raw.length > 10 ? raw.substring(0, 10) : raw;
    }
    final text = groupLinkCode(normalized);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
