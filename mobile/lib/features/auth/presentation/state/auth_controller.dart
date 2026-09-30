import 'package:flutter/widgets.dart';

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
      _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
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
      _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất khỏi tài khoản.
  Future<void> signOut() async {
    await _repository.signOut();
    _currentSession = null;
    _lastSentIdentifier = null;
    notifyListeners();
  }
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
