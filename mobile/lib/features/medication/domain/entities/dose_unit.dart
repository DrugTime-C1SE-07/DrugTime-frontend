/// Đơn vị đếm liều suy ra từ dạng bào chế của danh mục (API không trả đơn vị).
library;

/// Đơn vị dùng khi dạng bào chế không có hoặc không nhận ra.
const fallbackDoseUnit = 'liều';

/// Luật theo thứ tự ưu tiên: luật đầu tiên có từ khóa xuất hiện trong dạng bào chế thắng.
/// Từ khóa viết không dấu, chữ thường; dạng bào chế được chuẩn hóa cùng cách trước khi so.
const _rules = <(List<String>, String)>[
  (['goi'], 'gói'),
  (['ong'], 'ống'),
  (['dung dich', 'siro', 'hon dich', 'nhu dich'], 'ml'),
  (['lo', 'chai'], 'lọ'),
  (['vien', 'nang'], 'viên'),
  (['bot'], 'gói'),
  (['kem', 'gel', 'mo'], 'lần bôi'),
  (['xit'], 'nhát xịt'),
  (['nho'], 'giọt'),
];

/// Ví dụ: "Viên nén bao phim" → viên; "Thuốc bột pha hỗn dịch uống" → ml (hỗn dịch đứng
/// trước bột); "Thuốc bột (gói)" → gói; "Siro" → ml; `null` → [fallbackDoseUnit].
String doseUnitFor(String? dosageForm) {
  if (dosageForm == null) return fallbackDoseUnit;
  final words = _normalize(dosageForm);
  for (final (keywords, unit) in _rules) {
    if (keywords.any((k) => _containsWords(words, k))) return unit;
  }
  return fallbackDoseUnit;
}

/// So theo cả từ để `lo` không khớp trong `lop`, `mo` không khớp trong `mot`.
bool _containsWords(String text, String keyword) => ' $text '.contains(' $keyword ');

String _normalize(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_plain[char] ?? (RegExp(r'[a-z0-9]').hasMatch(char) ? char : ' '));
  }
  return buffer.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}

final Map<String, String> _plain = {
  for (final entry in const {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  }.entries)
    for (final char in entry.value.split('')) char: entry.key,
};
