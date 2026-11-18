import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/entities/allergy_profile.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/allergy_profile_repository.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';
import 'dietary_session.dart';

enum MealTabStatus { idle, loading, data, error }

class MealTabState {
  const MealTabState({
    this.status = MealTabStatus.idle,
    this.result,
    this.failure,
    this.mainIndex = 0,
    this.previousMainIndex,
    this.refreshing = false,
    this.refreshFailure,
  });

  final MealTabStatus status;
  final MealSuggestionResult? result;
  final MealSuggestionFailure? failure;

  /// Món đang ở thẻ "Dumi chọn"; "Đổi món" xoay vòng cục bộ, không gọi API (AC13).
  final int mainIndex;

  /// Món chính trước khi đổi: hiện trong dải "Món khác" kèm nút hoàn tác (Figma S05-D2).
  final int? previousMainIndex;

  /// Đang gọi "Gợi ý khác": giữ gợi ý cũ trên màn trong lúc chờ.
  final bool refreshing;
  final MealSuggestionFailure? refreshFailure;

  MealDish? get mainDish => result?.dishes[mainIndex];

  List<int> get otherIndexes => [
        for (var i = 0; i < (result?.dishes.length ?? 0); i++)
          if (i != mainIndex) i,
      ];
}

/// Trạng thái màn gợi ý bữa ăn. Gợi ý chỉ nằm trong bộ nhớ khi màn mở (AC19).
class MealSuggestionController extends ChangeNotifier {
  MealSuggestionController({
    required MealSuggestionRepository repository,
    required AllergyProfileRepository allergyRepository,
    required this.patientId,
    DietarySession? session,
    MealType? initialTab,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 3),
    this.pollWindow = const Duration(seconds: 30),
  })  : _repository = repository,
        _allergyRepository = allergyRepository,
        _session = session ?? DietarySession.instance,
        _now = now ?? DateTime.now {
    tab = initialTab ?? MealType.forVietnamTime(_now());
  }

  final MealSuggestionRepository _repository;
  final AllergyProfileRepository _allergyRepository;
  final DietarySession _session;
  final DateTime Function() _now;
  final String patientId;
  final Duration pollInterval;
  final Duration pollWindow;

  late MealType tab;
  AllergyProfile? allergy;
  bool allergyLoading = false;
  bool allergyFailed = false;

  final Map<MealType, MealTabState> _tabs = {
    for (final t in MealType.values) t: const MealTabState(),
  };
  final Map<MealType, int> _tokens = {for (final t in MealType.values) t: 0};

  /// Trạng thái ảnh mới nhất theo image_id (sau khi hỏi lại `GET /meal-images`).
  final Map<int, MealDishImage> _images = {};
  int? refreshesRemaining;
  Timer? _poll;
  DateTime? _pollStarted;
  bool _disposed = false;

  MealTabState get current => _tabs[tab]!;
  MealTabState stateOf(MealType type) => _tabs[type]!;

  bool get dietaryDeclared => _session.isDeclared;
  DietarySession get session => _session;
  bool get allergyReported => allergy?.toDeclaration() != null;

  MealDishImage? imageOf(MealDish dish) {
    final image = dish.image;
    if (image == null) return null;
    return _images[image.imageId] ?? image;
  }

  Future<Uint8List> imageBytes(MealDishImage image) =>
      _repository.imageBytes(image);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadAllergy() async {
    allergyLoading = true;
    allergyFailed = false;
    _notify();
    try {
      allergy = await _allergyRepository.load();
    } on Exception {
      allergyFailed = true;
    } finally {
      allergyLoading = false;
      _notify();
    }
  }

  /// Chuyển tab; tải tab mới chỉ khi chưa có kết quả và đủ khai báo (AC19).
  void selectTab(MealType type) {
    tab = type;
    _notify();
    if (_tabs[type]!.status == MealTabStatus.idle && canRequest) {
      unawaited(load(type));
    }
  }

  bool get canRequest => allergyReported && _session.isDeclared;

  void saveDietary({
    required DietaryDeclaration restrictions,
    required List<String> preferences,
  }) {
    _session
      ..restrictions = restrictions
      ..preferences = preferences;
    _notify();
  }

  /// Gọi API cho [type]. Chỉ chạy khi người dùng mở tab hoặc bấm "Thử lại": không tự retry.
  Future<void> load(MealType type) async {
    final declaration = allergy?.toDeclaration();
    final restrictions = _session.restrictions;
    if (declaration == null || restrictions == null) return;
    final token = _tokens[type]! + 1;
    _tokens[type] = token;
    _tabs[type] = const MealTabState(status: MealTabStatus.loading);
    _notify();
    try {
      final result = await _repository.suggest(
        patientId: patientId,
        mealType: type,
        allergies: declaration,
        restrictions: restrictions,
        preferences: _session.preferences,
      );
      if (_disposed || _tokens[type] != token) return; // response muộn của lần gọi cũ
      _tabs[type] = MealTabState(status: MealTabStatus.data, result: result);
      refreshesRemaining = result.refreshesRemaining;
      _startPolling();
    } on MealSuggestionFailure catch (failure) {
      if (_disposed || _tokens[type] != token) return;
      _tabs[type] = MealTabState(status: MealTabStatus.error, failure: failure);
    }
    _notify();
  }

  bool get canRefresh =>
      current.status == MealTabStatus.data &&
      !current.refreshing &&
      (refreshesRemaining ?? 0) > 0;

  /// "Gợi ý khác": gửi `previous_suggestion_id` (AC14). Lỗi thì giữ gợi ý đang có.
  Future<void> refresh() async {
    final type = tab;
    final state = _tabs[type]!;
    final previous = state.result;
    final declaration = allergy?.toDeclaration();
    final restrictions = _session.restrictions;
    if (previous == null || declaration == null || restrictions == null) return;
    final token = _tokens[type]! + 1;
    _tokens[type] = token;
    _tabs[type] = MealTabState(
      status: MealTabStatus.data,
      result: previous,
      mainIndex: state.mainIndex,
      previousMainIndex: state.previousMainIndex,
      refreshing: true,
    );
    _notify();
    try {
      final result = await _repository.suggest(
        patientId: patientId,
        mealType: type,
        allergies: declaration,
        restrictions: restrictions,
        preferences: _session.preferences,
        previousSuggestionId: previous.suggestionId,
      );
      if (_disposed || _tokens[type] != token) return;
      _tabs[type] = MealTabState(status: MealTabStatus.data, result: result);
      refreshesRemaining = result.refreshesRemaining;
      _startPolling();
    } on MealSuggestionFailure catch (failure) {
      if (_disposed || _tokens[type] != token) return;
      if (failure.kind == MealFailureKind.refreshLimit) refreshesRemaining = 0;
      if (failure.kind == MealFailureKind.previousNotFound) {
        // Gợi ý trước không còn dùng được: gợi ý lại từ đầu, không kèm gợi ý cũ.
        _notify();
        await load(type);
        return;
      }
      _tabs[type] = MealTabState(
        status: MealTabStatus.data,
        result: previous,
        mainIndex: state.mainIndex,
        previousMainIndex: state.previousMainIndex,
        refreshFailure: failure,
      );
    }
    _notify();
  }

  /// "Đổi món": món kế tiếp lên thẻ chính, xoay vòng; món cũ có nút hoàn tác (AC13).
  void rotate() {
    final state = current;
    final count = state.result?.dishes.length ?? 0;
    if (count < 2) return;
    _tabs[tab] = MealTabState(
      status: state.status,
      result: state.result,
      mainIndex: (state.mainIndex + 1) % count,
      previousMainIndex: state.mainIndex,
    );
    _notify();
  }

  /// Đưa một món lên thẻ chính (bấm hoàn tác hoặc chọn từ dải "Món khác").
  void promote(int index) {
    final state = current;
    final count = state.result?.dishes.length ?? 0;
    if (index < 0 || index >= count || index == state.mainIndex) return;
    _tabs[tab] = MealTabState(
      status: state.status,
      result: state.result,
      mainIndex: index,
      previousMainIndex: state.mainIndex,
    );
    _notify();
  }

  List<int> _pendingImageIds() => {
        for (final s in _tabs.values)
          for (final dish in s.result?.dishes ?? const <MealDish>[])
            if (imageOf(dish) case final image?
                when image.status == MealImageStatus.pending)
              image.imageId,
      }.toList();

  void _startPolling() {
    if (_pendingImageIds().isEmpty) return;
    _pollStarted = _now();
    _poll ??= Timer.periodic(pollInterval, (_) => unawaited(_pollOnce()));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pollOnce() async {
    final ids = _pendingImageIds();
    final started = _pollStarted;
    if (_disposed ||
        ids.isEmpty ||
        started == null ||
        _now().difference(started) >= pollWindow) {
      // Hết 30 giây vẫn pending: hiện ảnh mặc định, không hỏi nữa.
      _stopPolling();
      return;
    }
    try {
      final states = await _repository.imageStates(ids);
      if (_disposed) return;
      for (final s in states) {
        _images[s.imageId] = s;
      }
      _notify();
    } on MealSuggestionFailure {
      // Lỗi tạm thời khi hỏi ảnh: thử lại ở nhịp sau, gợi ý vẫn hiển thị.
    }
  }

  @visibleForTesting
  bool get isPolling => _poll != null;

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    super.dispose();
  }
}
