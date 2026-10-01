/// Phương thức đăng nhập và các hàm kiểm tra hợp lệ thông tin người dùng.
library;

enum LoginMethod {
  phone('Số điện thoại'),
  email('Email');

  const LoginMethod(this.label);
  final String label;

  bool get isPhone => this == LoginMethod.phone;
  bool get isEmail => this == LoginMethod.email;
}

abstract final class AuthValidator {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Chuẩn hoá số điện thoại về định dạng E.164 (+84...) cho Backend API.
  static String normalizePhone(String raw) {
    var phone = raw.replaceAll(' ', '').replaceAll('-', '').trim();
    if (phone.startsWith('0') && phone.length > 1) {
      phone = '+84${phone.substring(1)}';
    }
    return phone;
  }

  /// Làm sạch số điện thoại để hiển thị hoặc xử lý cục bộ.
  static String cleanDigits(String raw) {
    return raw.replaceAll(' ', '').replaceAll('-', '').trim();
  }

  /// Kiểm tra số điện thoại có hợp lệ hay không (9-11 chữ số).
  static bool isValidPhone(String raw) {
    final cleaned = cleanDigits(raw);
    if (cleaned.isEmpty) return false;

    if (cleaned.startsWith('+84')) {
      final digits = cleaned.substring(3);
      return digits.length >= 9 && digits.length <= 10 && int.tryParse(digits) != null;
    }
    if (cleaned.startsWith('0')) {
      final digits = cleaned.substring(1);
      return digits.length >= 9 && digits.length <= 10 && int.tryParse(digits) != null;
    }
    return cleaned.length >= 9 && cleaned.length <= 11 && int.tryParse(cleaned) != null;
  }

  /// Kiểm tra định dạng email hợp lệ.
  static bool isValidEmail(String raw) {
    final email = raw.trim();
    return email.isNotEmpty && _emailRegex.hasMatch(email);
  }

  /// Che bớt thông tin số điện thoại để đảm bảo tính riêng tư (VD: 904****87).
  static String maskPhone(String raw) {
    if (raw.contains('*')) return raw;
    var digits = cleanDigits(raw).replaceAll('+', '');
    if (digits.startsWith('84') && digits.length >= 11) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length < 5) {
      return raw.trim().isEmpty ? '904****87' : raw;
    }
    final prefix = digits.substring(0, 3);
    final suffix = digits.substring(digits.length - 2);
    return '$prefix****$suffix';
  }

  /// Che bớt thông tin email để đảm bảo tính riêng tư (VD: viet****@gmail.com).
  static String maskEmail(String raw) {
    if (raw.contains('*')) return raw;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'viet****@gmail.com';

    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0) return trimmed;

    final name = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex); // includes '@...'

    final visibleLen = name.length >= 4 ? 4 : (name.length > 2 ? name.length - 1 : 1);
    final prefix = name.substring(0, visibleLen);
    return '$prefix****$domain';
  }
}
