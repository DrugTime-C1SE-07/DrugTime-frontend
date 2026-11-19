import 'package:flutter/widgets.dart';

import '../../domain/entities/family_link_code.dart';
import '../../domain/entities/family_link_code_failure.dart';
import '../../domain/repositories/family_link_code_repository.dart';

class FamilyLinkCodeController extends ChangeNotifier {
  FamilyLinkCodeController(this._repository);

  final FamilyLinkCodeRepository _repository;

  FamilyLinkCode? _code;
  FamilyLinkCodeFailure? _failure;
  bool _isLoading = false;
  bool _hasLoaded = false;
  int _generation = 0;

  FamilyLinkCode? get code => _code;
  FamilyLinkCodeFailure? get failure => _failure;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    if (_isLoading) return;
    final generation = ++_generation;
    _isLoading = true;
    _code = null;
    _failure = null;
    notifyListeners();
    try {
      final code = await _repository.fetch();
      if (generation != _generation) return;
      _code = code;
      _hasLoaded = true;
    } on FamilyLinkCodeFailure catch (failure) {
      if (generation != _generation) return;
      _failure = failure;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _code = null;
    _failure = null;
    _isLoading = false;
    _hasLoaded = false;
    notifyListeners();
  }
}

class FamilyLinkCodeScope extends InheritedNotifier<FamilyLinkCodeController> {
  const FamilyLinkCodeScope({
    super.key,
    required FamilyLinkCodeController controller,
    required super.child,
  }) : super(notifier: controller);

  static FamilyLinkCodeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FamilyLinkCodeScope>();
    assert(scope != null,
        'Không tìm thấy FamilyLinkCodeScope phía trên widget này');
    return scope!.notifier!;
  }

  static FamilyLinkCodeController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FamilyLinkCodeScope>();
    assert(scope != null,
        'Không tìm thấy FamilyLinkCodeScope phía trên widget này');
    return scope!.notifier!;
  }
}
