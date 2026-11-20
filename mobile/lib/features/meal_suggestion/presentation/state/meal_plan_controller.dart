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
    this.pageIndex = 0,
  });

  final MealTabStatus status;
  final MealSuggestionResult? result;
  final MealSuggestionFailure? failure;

  /// Thẻ đang xem trong chồng thẻ của bữa này.
  final int pageIndex;

  List<MealDish> get dishes => result?.dishes ?? const [];

  MealTabState copyWith({int? pageIndex}) => MealTabState(
        status: status,
        result: result,
        failure: failure,
        pageIndex: pageIndex ?? this.pageIndex,
      );
}

/// Ngày theo giờ Việt Nam (múi giờ cố định, bất biến 7) dạng `yyyy-mm-dd`.
String vietnamDay(DateTime now) {
  final vn = now.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${vn.year}-${two(vn.month)}-${two(vn.day)}';
}

/// Thực đơn hôm nay (3 bữa) ở mức phiên app.
///
/// Chỉ giữ trong bộ nhớ, theo `(tài khoản, ngày giờ VN)`; khóa đổi thì xóa sạch (AC12).
/// Đây là dữ liệu đã nhận, không phải quyết định quyền: mọi lời gọi mới vẫn qua server.
class MealPlanController extends ChangeNotifier {
  MealPlanController({
    required MealSuggestionRepository repository,
    required AllergyProfileRepository allergyRepository,
    DietarySession? session,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 2),
    this.pollWindow = const Duration(seconds: 30),
    this.imageWaitLimit = const Duration(seconds: 20),
    this.imagePrefetchConcurrency = 3,
  })  : _repository = repository,
        _allergyRepository = allergyRepository,
        _session = session ?? DietarySession.instance,
        _now = now ?? DateTime.now {
    tab = MealType.forVietnamTime(_now());
  }

  final MealSuggestionRepository _repository;
  final AllergyProfileRepository _allergyRepository;
  final DietarySession _session;
  final DateTime Function() _now;
  final Duration pollInterval;
  final Duration pollWindow;

  /// Màn chờ giữ tối đa chừng này (tính từ lúc API trả gợi ý) để đợi ảnh của bữa sắp hiển thị
  /// (adhoc-20261120-meal-image-loading, AC5). Hết giờ thì món chưa có ảnh dùng ảnh mặc định.
  final Duration imageWaitLimit;

  /// Số ảnh tải nội dung song song tối đa (AC7).
  final int imagePrefetchConcurrency;

  String? _userId;
  String? _day;

  late MealType tab;
  AllergyProfile? allergy;
  bool allergyLoading = false;
  bool allergyFailed = false;

  final Map<MealType, MealTabState> _tabs = {
    for (final t in MealType.values) t: const MealTabState(),
  };
  final Map<MealType, int> _tokens = {for (final t in MealType.values) t: 0};
  final Map<int, MealDishImage> _images = {};

  /// Nội dung ảnh đã tải sẵn (đọc đồng bộ để ảnh hiện ngay ở khung hình đầu, AC4).
  final Map<int, Uint8List> _bytes = {};
  final List<MealDishImage> _fetchQueue = [];
  final Set<int> _queued = {};
  int _fetching = 0;

  /// Đổi khi xóa thực đơn: kết quả tải về muộn của thực đơn cũ bị bỏ.
  int _generation = 0;

  /// Thời điểm API trả gợi ý của từng bữa, để tính thời gian chờ ảnh.
  final Map<MealType, DateTime> _resultAt = {};
  int? refreshesRemaining;
  Timer? _poll;
  DateTime? _pollStarted;
  bool _disposed = false;

  String? get patientId => _userId;
  DateTime now() => _now();

  MealTabState stateOf(MealType type) => _tabs[type]!;
  MealTabState get current => _tabs[tab]!;

  /// Có ít nhất một bữa đã có kết quả (để mở thẳng màn kết quả, không gọi API).
  bool get hasMenu => _tabs.values.any((s) => s.status == MealTabStatus.data);

  bool get isAnalyzing =>
      _tabs.values.any((s) => s.status == MealTabStatus.loading);

  bool get dietaryDeclared => _session.isDeclared;
  DietarySession get session => _session;
  bool get allergyReported => allergy?.toDeclaration() != null;
  bool get canRequest => allergyReported && _session.isDeclared;

  /// Gắn tài khoản; tài khoản hoặc ngày VN khác lần trước thì xóa thực đơn cũ.
  void bind(String? userId) {
    final day = vietnamDay(_now());
    if (userId == _userId && day == _day) return;
    final userChanged = userId != _userId;
    _userId = userId;
    _day = day;
    _clearMenu();
    if (userChanged) {
      allergy = null;
      allergyFailed = false;
    }
    tab = MealType.forVietnamTime(_now());
    _notify();
  }

  /// Xóa thực đơn trong bộ nhớ (đăng xuất, thu hồi `ai_meal`, khai báo đổi, qua ngày).
  void reset() {
    _clearMenu();
    _notify();
  }

  /// Đăng xuất / đổi tài khoản: quên luôn tài khoản và hồ sơ dị ứng đã đọc.
  void signOut() {
    _userId = null;
    _day = null;
    allergy = null;
    allergyFailed = false;
    reset();
  }

  void _clearMenu() {
    for (final t in MealType.values) {
      _tokens[t] = _tokens[t]! + 1; // bỏ mọi response về muộn (AC16)
      _tabs[t] = const MealTabState();
    }
    _images.clear();
    _bytes.clear();
    _fetchQueue.clear();
    _queued.clear();
    _fetching = 0;
    _generation++;
    _resultAt.clear();
    refreshesRemaining = null;
    _stopPolling();
  }

  MealDishImage? imageOf(MealDish dish) {
    final image = dish.image;
    if (image == null) return null;
    return _images[image.imageId] ?? image;
  }

  Future<Uint8List> imageBytes(MealDishImage image) =>
      _repository.imageBytes(image);

  /// Nội dung ảnh đã tải sẵn, hoặc `null` nếu chưa có.
  Uint8List? cachedImageBytes(MealDishImage image) => _bytes[image.imageId];

  /// Món hiện đầu tiên của [type] (thẻ ở `pageIndex`, mặc định thẻ "Dumi chọn"), hoặc `null`
  /// khi bữa chưa có món.
  MealDish? _leadDish(MealType type) {
    final state = _tabs[type]!;
    final dishes = state.dishes;
    if (dishes.isEmpty) return null;
    return dishes[state.pageIndex.clamp(0, dishes.length - 1)];
  }

  /// Món hiện đầu tiên của [type] đã sẵn sàng hiển thị ảnh: không có ảnh, ảnh lỗi, hoặc ảnh
  /// `ready` và nội dung đã tải xong. Ảnh các món khác không tính (AC4, AC6).
  bool leadImageSettled(MealType type) {
    final dish = _leadDish(type);
    final image = dish == null ? null : imageOf(dish);
    if (image == null || image.status == MealImageStatus.failed) return true;
    return image.isReady && _bytes.containsKey(image.imageId);
  }

  /// Đã chờ ảnh của [type] đủ [imageWaitLimit] (hoặc bữa chưa có kết quả nên không cần chờ) (AC5).
  bool imageWaitExpired(MealType type) {
    final at = _resultAt[type];
    return at == null || _now().difference(at) >= imageWaitLimit;
  }

  /// Thời gian chờ ảnh còn lại của [type]; `null` khi bữa chưa có kết quả.
  Duration? imageWaitRemaining(MealType type) {
    final at = _resultAt[type];
    if (at == null) return null;
    final left = imageWaitLimit - _now().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadAllergy() async {
    allergyLoading = true;
    allergyFailed = false;
    _notify();
    try {
      final loaded = await _allergyRepository.load();
      final before = allergy?.toDeclaration()?.toJson().toString();
      allergy = loaded;
      // Dị ứng đổi so với lần đã dùng để gợi ý: thực đơn cũ không còn đúng.
      if (before != null &&
          before != loaded.toDeclaration()?.toJson().toString()) {
        _clearMenu();
      }
    } on Exception {
      allergyFailed = true;
    } finally {
      allergyLoading = false;
      _notify();
    }
  }

  void saveDietary({
    required DietaryDeclaration restrictions,
    required List<String> preferences,
  }) {
    final before = _session.restrictions?.toJson().toString();
    final beforePrefs = _session.preferences.join('|');
    _session
      ..restrictions = restrictions
      ..preferences = preferences;
    if (before != null &&
        (before != restrictions.toJson().toString() ||
            beforePrefs != preferences.join('|'))) {
      _clearMenu();
    }
    _notify();
  }

  void selectTab(MealType type) {
    if (tab == type) return;
    tab = type;
    _notify();
  }

  void setPage(MealType type, int index) {
    final state = _tabs[type]!;
    if (state.pageIndex == index) return;
    _tabs[type] = state.copyWith(pageIndex: index);
    // Không báo listener: deck tự giữ vị trí, tránh dựng lại khi đang vuốt.
  }

  /// Bấm "Dumi AI": gửi đồng thời 3 bữa, không chờ nhau (AC3).
  Future<void> analyze() => Future.wait([
        for (final t in MealType.values) load(t),
      ]);

  /// Gọi lại riêng một bữa lỗi (AC6).
  Future<void> retryMeal(MealType type) => load(type);

  /// Gọi lại các bữa lỗi (lỗi toàn bộ → "Thử lại" cả 3).
  Future<void> retryFailed() => Future.wait([
        for (final t in MealType.values)
          if (_tabs[t]!.status != MealTabStatus.data) load(t),
      ]);

  Future<void> load(MealType type) async {
    final declaration = allergy?.toDeclaration();
    final restrictions = _session.restrictions;
    final patient = _userId;
    if (declaration == null || restrictions == null || patient == null) {
      return;
    }
    final token = _tokens[type]! + 1;
    _tokens[type] = token;
    _tabs[type] = const MealTabState(status: MealTabStatus.loading);
    _notify();
    try {
      final result = await _repository.suggest(
        patientId: patient,
        mealType: type,
        allergies: declaration,
        restrictions: restrictions,
        preferences: _session.preferences,
      );
      if (_disposed || _tokens[type] != token) return; // response muộn
      _tabs[type] = MealTabState(status: MealTabStatus.data, result: result);
      _resultAt[type] = _now();
      refreshesRemaining = result.refreshesRemaining;
      _startPolling();
      _prefetchReady();
    } on MealSuggestionFailure catch (failure) {
      if (_disposed || _tokens[type] != token) return;
      _tabs[type] = MealTabState(status: MealTabStatus.error, failure: failure);
    }
    _notify();
  }

  MealSuggestionFailure? lastRefreshFailure;

  bool get refreshLocked => (refreshesRemaining ?? 0) <= 0;

  /// "Gợi ý khác" cho riêng [type], gửi `previous_suggestion_id` (AC9).
  ///
  /// Trả `true` khi có danh sách mới. Lỗi thì giữ danh sách cũ; hết lượt (429) đặt lượt về 0 (AC9b).
  Future<bool> refresh(MealType type) async {
    final state = _tabs[type]!;
    final previous = state.result;
    final declaration = allergy?.toDeclaration();
    final restrictions = _session.restrictions;
    final patient = _userId;
    lastRefreshFailure = null;
    if (previous == null ||
        declaration == null ||
        restrictions == null ||
        patient == null) {
      return false;
    }
    final token = _tokens[type]! + 1;
    _tokens[type] = token;
    try {
      final result = await _repository.suggest(
        patientId: patient,
        mealType: type,
        allergies: declaration,
        restrictions: restrictions,
        preferences: _session.preferences,
        previousSuggestionId: previous.suggestionId,
      );
      if (_disposed || _tokens[type] != token) return false;
      _tabs[type] = MealTabState(status: MealTabStatus.data, result: result);
      _resultAt[type] = _now();
      refreshesRemaining = result.refreshesRemaining;
      _startPolling();
      _prefetchReady();
      _notify();
      return true;
    } on MealSuggestionFailure catch (failure) {
      if (_disposed || _tokens[type] != token) return false;
      if (failure.kind == MealFailureKind.previousNotFound) {
        // Gợi ý trước không còn dùng được: gợi ý lại từ đầu cho bữa này.
        await load(type);
        return _tabs[type]!.status == MealTabStatus.data;
      }
      if (failure.kind == MealFailureKind.refreshLimit) refreshesRemaining = 0;
      lastRefreshFailure = failure;
      _notify();
      return false;
    }
  }

  List<int> _pendingImageIds() => {
        for (final s in _tabs.values)
          for (final dish in s.dishes)
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
    if (_disposed || ids.isEmpty || started == null) {
      _stopPolling();
      return;
    }
    if (_now().difference(started) >= pollWindow) {
      // Hết 30 giây vẫn pending (Worker không chạy, kho ảnh tắt…): coi như không có ảnh để
      // hiện ảnh giữ chỗ, không để vòng xoay quay mãi.
      _stopPolling();
      for (final id in ids) {
        _images[id] =
            MealDishImage(imageId: id, status: MealImageStatus.failed);
      }
      _notify();
      return;
    }
    try {
      final states = await _repository.imageStates(ids);
      if (_disposed) return;
      for (final s in states) {
        _images[s.imageId] = s;
      }
      _prefetchReady();
      _notify();
    } on MealSuggestionFailure {
      // Lỗi tạm thời khi hỏi ảnh: thử lại ở nhịp sau, gợi ý vẫn hiển thị.
    }
  }

  /// Đưa ảnh `ready` chưa có nội dung vào hàng đợi tải sẵn (AC4, AC7). Ảnh của món hiện đầu
  /// tiên mỗi bữa vào đầu hàng, ảnh khác vào cuối hàng.
  void _prefetchReady() {
    final lead = <MealDishImage>[];
    for (final type in MealType.values) {
      final leadDish = _leadDish(type);
      for (final dish in _tabs[type]!.dishes) {
        final image = imageOf(dish);
        if (image == null || !image.isReady) continue;
        final id = image.imageId;
        if (_bytes.containsKey(id) || !_queued.add(id)) continue;
        if (identical(dish, leadDish)) {
          lead.add(image);
        } else {
          _fetchQueue.add(image);
        }
      }
    }
    _fetchQueue.insertAll(0, lead);
    _drainFetchQueue();
  }

  void _drainFetchQueue() {
    while (!_disposed &&
        _fetching < imagePrefetchConcurrency &&
        _fetchQueue.isNotEmpty) {
      final image = _fetchQueue.removeAt(0);
      _fetching++;
      unawaited(_fetchBytes(image, _generation));
    }
  }

  Future<void> _fetchBytes(MealDishImage image, int generation) async {
    Uint8List? bytes;
    try {
      bytes = await _repository.imageBytes(image);
    } on Exception {
      bytes = null; // tải lỗi: coi như không có ảnh, hiện ảnh mặc định (AC8)
    }
    if (_disposed || generation != _generation) return;
    _fetching--;
    if (bytes != null) {
      _bytes[image.imageId] = bytes;
    } else {
      _images[image.imageId] =
          MealDishImage(imageId: image.imageId, status: MealImageStatus.failed);
    }
    _notify();
    _drainFetchQueue();
  }

  @visibleForTesting
  bool get isPolling => _poll != null;

  @visibleForTesting
  int get imagesFetching => _fetching;

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    super.dispose();
  }
}
