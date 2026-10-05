import 'package:flutter/widgets.dart';

import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';
import '../../domain/repositories/consent_repository.dart';

/// Trạng thái consent của người dùng đang đăng nhập, đọc từ server.
///
/// Chỉ dùng để hiển thị và điều hướng (màn đồng ý, công tắc); không dùng để quyết định quyền:
/// server kiểm consent ở mỗi request.
class ConsentController extends ChangeNotifier {
  ConsentController(this._repository);

  final ConsentRepository _repository;

  Map<ConsentPurpose, ConsentState> _states = const {};
  bool _isLoading = false;
  bool _loaded = false;
  ConsentFailure? _loadError;

  bool get isLoading => _isLoading;

  /// Đã tải thành công ít nhất một lần kể từ lần [clear] gần nhất.
  bool get isLoaded => _loaded;
  ConsentFailure? get loadError => _loadError;

  bool isGranted(ConsentPurpose purpose) => _states[purpose]?.granted ?? false;
  bool get hasHealthData => isGranted(ConsentPurpose.healthData);

  /// Chưa đồng ý điều khoản, hoặc đã đồng ý bản cũ hơn bản server đang công bố.
  bool get needsTerms {
    final terms = _states[ConsentPurpose.terms];
    return terms == null ||
        !terms.granted ||
        terms.documentVersion != terms.currentDocumentVersion;
  }

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final states = await _repository.fetchAll();
      _states = {for (final s in states) s.purpose: s};
      _loaded = true;
    } on ConsentFailure catch (failure) {
      _loadError = failure;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ném [ConsentFailure] khi lỗi; trạng thái giữ nguyên.
  Future<void> grant(ConsentPurpose purpose) => _apply(() => _repository.grant(purpose));

  /// Ném [ConsentFailure] khi lỗi; trạng thái giữ nguyên.
  Future<void> withdraw(ConsentPurpose purpose) => _apply(() => _repository.withdraw(purpose));

  /// Đăng xuất: bỏ trạng thái của người dùng trước.
  void clear() {
    _states = const {};
    _loaded = false;
    _loadError = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _apply(Future<ConsentState> Function() write) async {
    final state = await write();
    _states = {..._states, state.purpose: state};
    notifyListeners();
  }
}

class ConsentScope extends InheritedNotifier<ConsentController> {
  const ConsentScope({
    super.key,
    required ConsentController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Lấy controller và đăng ký rebuild khi trạng thái thay đổi.
  static ConsentController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ConsentScope>();
    assert(scope != null, 'Không tìm thấy ConsentScope phía trên widget này');
    return scope!.notifier!;
  }

  /// Lấy controller mà không rebuild — dùng trong callback / initState.
  static ConsentController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ConsentScope>();
    assert(scope != null, 'Không tìm thấy ConsentScope phía trên widget này');
    return scope!.notifier!;
  }
}
