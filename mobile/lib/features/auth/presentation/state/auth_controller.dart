import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';

import '../../data/sources/auth_api_exception.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/login_method.dart';
import '../../domain/repositories/auth_repository.dart';

/// Quản lý trạng thái và luồng nghiệp vụ đăng nhập của ứng dụng (ChangeNotifier).
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  LoginMethod _method = LoginMethod.phone;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  String? _lastSentIdentifier;
  AuthSession? _currentSession;

  LoginMethod get method => _method;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get lastSentIdentifier => _lastSentIdentifier;
  AuthSession? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession?.isExpired == false;

  /// Đã đăng nhập nhưng chưa có hồ sơ (người mới): phải qua màn hoàn thiện hồ sơ.
  bool get needsProfile => isAuthenticated && _currentSession?.profileComplete == false;

  /// Giới tính màn hồ sơ gửi lên API.
  static const genders = {'nam': 'Nam', 'nu': 'Nữ', 'khac': 'Khác'};

  /// Đổi phương thức đăng nhập giữa Số điện thoại và Email.
  void setMethod(LoginMethod newMethod) {
    if (_method != newMethod) {
      _method = newMethod;
      _errorMessage = null;
      _infoMessage = null;
      notifyListeners();
    }
  }

  /// Xoá thông báo lỗi / tin nhắn hiện tại.
  void clearMessages() {
    if (_errorMessage != null || _infoMessage != null) {
      _errorMessage = null;
      _infoMessage = null;
      notifyListeners();
    }
  }

  /// Khởi tạo và kiểm tra phiên làm việc đã lưu.
  Future<void> initSession() async {
    _isLoading = true;
    notifyListeners();
    _currentSession = await _repository.getCurrentSession();
    _isLoading = false;
    notifyListeners();
  }

  /// Gửi mã OTP sau khi kiểm tra tính hợp lệ của định dạng dữ liệu đầu vào.
  Future<bool> requestOtp(String rawIdentifier) async {
    clearMessages();

    if (_method == LoginMethod.phone) {
      final clean = AuthValidator.cleanDigits(rawIdentifier);
      if (clean.isEmpty) {
        _errorMessage = 'Vui lòng nhập số điện thoại';
        notifyListeners();
        return false;
      }
      if (!AuthValidator.isValidPhone(clean)) {
        _errorMessage = 'Số điện thoại không hợp lệ (9-11 chữ số)';
        notifyListeners();
        return false;
      }

      final normalized = AuthValidator.normalizePhone(clean);
      return _executeRequestOtp(phone: normalized, displayTarget: '+84 $clean');
    } else {
      final email = rawIdentifier.trim();
      if (email.isEmpty) {
        _errorMessage = 'Vui lòng nhập địa chỉ email';
        notifyListeners();
        return false;
      }
      if (!AuthValidator.isValidEmail(email)) {
        _errorMessage = 'Địa chỉ email không đúng định dạng';
        notifyListeners();
        return false;
      }

      return _executeRequestOtp(email: email, displayTarget: email);
    }
  }

  /// Gửi lại mã tới đúng số/email đã chuẩn hóa ở lần gửi trước.
  Future<bool> resendOtp() async {
    final target = _lastSentIdentifier;
    if (target == null) {
      _errorMessage = 'Vui lòng nhập lại số điện thoại hoặc email';
      notifyListeners();
      return false;
    }
    clearMessages();
    final isPhone = _method == LoginMethod.phone;
    return _executeRequestOtp(
      phone: isPhone ? target : null,
      email: isPhone ? null : target,
      displayTarget: target,
    );
  }

  Future<bool> _executeRequestOtp({
    String? phone,
    String? email,
    required String displayTarget,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestOtp(phone: phone, email: email);
      _lastSentIdentifier = phone ?? email;
      _infoMessage = 'Đã gửi mã OTP đến $displayTarget';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _messageFor(e, _AuthStep.requestOtp);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Xác thực mã OTP nhận được từ người dùng.
  Future<bool> verifyOtp({required String token}) async {
    if (token.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập mã OTP';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isPhone = _method == LoginMethod.phone;
      final session = await _repository.verifyOtp(
        phone: isPhone ? _lastSentIdentifier : null,
        email: !isPhone ? _lastSentIdentifier : null,
        token: token.trim(),
      );
      _currentSession = session;
      _infoMessage = 'Đăng nhập thành công';
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _messageFor(e, _AuthStep.verifyOtp);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Lưu hồ sơ cơ bản. Kiểm dữ liệu tại chỗ trước, chỉ gọi API khi hợp lệ.
  Future<bool> completeProfile({
    required String fullName,
    required DateTime? dateOfBirth,
    required String? gender,
  }) async {
    clearMessages();
    final name = fullName.trim();
    final today = DateUtils.dateOnly(DateTime.now());
    final String? invalid;
    if (name.isEmpty) {
      invalid = 'Vui lòng nhập họ tên';
    } else if (dateOfBirth == null) {
      invalid = 'Vui lòng chọn ngày sinh';
    } else if (DateUtils.dateOnly(dateOfBirth).isAfter(today)) {
      invalid = 'Ngày sinh không được sau hôm nay';
    } else if (gender == null || !genders.containsKey(gender)) {
      invalid = 'Vui lòng chọn giới tính';
    } else {
      invalid = null;
    }
    if (invalid != null) {
      _errorMessage = invalid;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();
    try {
      _currentSession = await _repository.completeProfile(
        fullName: name,
        dateOfBirth: dateOfBirth!,
        gender: gender!,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = _messageFor(e, _AuthStep.completeProfile);
      if (e is AuthApiException && e.kind == AuthErrorKind.invalidCredentials) {
        await handleUnauthorized();
        _errorMessage = _messageFor(e, _AuthStep.completeProfile);
      }
      notifyListeners();
      return false;
    }
  }

  /// API báo phiên không còn hiệu lực (401): xóa phiên để app quay về màn Đăng nhập.
  Future<void> handleUnauthorized() async {
    if (_currentSession == null) return;
    await _repository.signOut();
    _currentSession = null;
    _lastSentIdentifier = null;
    notifyListeners();
  }

  /// Đăng xuất khỏi tài khoản.
  Future<void> signOut() async {
    await _repository.signOut();
    _currentSession = null;
    _lastSentIdentifier = null;
    notifyListeners();
  }
}

enum _AuthStep { requestOtp, verifyOtp, completeProfile }

/// Thông điệp tiếng Việt theo loại lỗi; không hiển thị nguyên `detail` của backend.
String _messageFor(Object error, _AuthStep step) {
  if (error is! AuthApiException) {
    return 'Đã có lỗi xảy ra, vui lòng thử lại';
  }
  return switch (error.kind) {
    AuthErrorKind.invalidCredentials => step == _AuthStep.completeProfile
        ? 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại'
        : 'Mã OTP không đúng hoặc đã hết hạn',
    AuthErrorKind.adminMustUseWeb =>
      'Tài khoản quản trị vui lòng đăng nhập trên trang quản trị',
    AuthErrorKind.invalidInput => switch (error.code) {
        'invalid_phone' => 'Số điện thoại không hợp lệ',
        'invalid_email' => 'Địa chỉ email không đúng định dạng',
        'invalid_date_of_birth' => 'Ngày sinh không được sau hôm nay',
        'invalid_full_name' => 'Vui lòng nhập họ tên',
        _ => 'Thông tin chưa hợp lệ, vui lòng kiểm tra lại',
      },
    AuthErrorKind.rateLimited => 'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút',
    AuthErrorKind.unavailable => 'Hệ thống đang bận, vui lòng thử lại sau',
    AuthErrorKind.network => 'Không kết nối được máy chủ, vui lòng kiểm tra mạng',
    AuthErrorKind.unexpected => 'Đã có lỗi xảy ra, vui lòng thử lại',
  };
}

/// Đưa [AuthController] xuống cây widget, rebuild khi trạng thái xác thực đổi.
/// Tương tự như [MedicationScope].
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Lấy controller và đăng ký rebuild khi dữ liệu đổi.
  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'Không tìm thấy AuthScope phía trên widget này');
    return scope!.notifier!;
  }

  /// Lấy controller mà không rebuild — dùng trong callback hoặc initState.
  static AuthController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'Không tìm thấy AuthScope phía trên widget này');
    return scope!.notifier!;
  }

  /// Tìm AuthController an toàn (có thể null nếu màn hình chạy độc lập không qua App).
  static AuthController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }
}
