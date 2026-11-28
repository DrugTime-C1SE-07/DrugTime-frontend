import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../../../patient_monitor/presentation/widgets/lost_access_view.dart';
import '../../../profile/presentation/state/profile_controller.dart';
import '../../data/meal_choice_store.dart';
import '../../data/repositories/family_meal_suggestion_repository.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../analyzing/analyzing_view.dart';
import '../state/meal_choice_controller.dart';
import '../state/meal_plan_controller.dart';
import '../state/meal_plan_scope.dart';
import '../widgets/dish_deck.dart';
import '../widgets/meal_greeting.dart';
import '../widgets/meal_setup_sheet.dart';
import '../widgets/meal_tabs.dart';
import '../widgets/meal_ui.dart';
import '../widgets/meal_widgets.dart';
import '../widgets/refresh_button.dart';
import 'meal_detail_screens.dart';

/// Tham số route gợi ý bữa ăn: mở sẵn ở bữa [initialMeal] (từ hàng Trang chủ hoặc widget).
class MealRouteArgs {
  const MealRouteArgs({this.initialMeal});
  final MealType? initialMeal;
}

/// Luồng gợi ý bữa ăn (Dumi AI): sheet "Dumi cần biết" (nếu thiếu) → màn chờ 3 bữa → kết quả.
///
/// Thực đơn trong ngày đã có thì vào thẳng kết quả, không gọi API (AC12). Màn này là màn kết
/// quả; màn chờ được đẩy lên trên rồi pop về, để đĩa món bay vào thẻ (Hero).
class MealSuggestionScreen extends StatefulWidget {
  const MealSuggestionScreen({
    super.key,
    required this.onDeclareAllergy,
    this.initialMeal,
    this.patientId,
    this.patientName,
    this.caregiverMode = false,
    this.accessRevokedListenable,
    this.isAccessRevoked,
    this.onAccessDenied,
  });

  /// Mở màn khai dị ứng (router truyền vào).
  /// Opens the real allergy declaration; resolves `true` once it is saved (N7, AC12).
  final Future<bool?> Function(BuildContext context) onDeclareAllergy;
  final MealType? initialMeal;

  /// Mặc định là người dùng đang đăng nhập (gợi ý chỉ cho chính chủ).
  final String? patientId;

  /// Tên người bệnh hiển thị khi xem từ phía người thân (`caregiverMode: true`).
  final String? patientName;

  /// `true`: chế độ người thân chỉ xem (PB39, QD-27), cô lập khỏi consent/hồ sơ chính chủ.
  final bool caregiverMode;

  /// Theo dõi thay đổi quyền từ màn theo dõi người thân trong lúc màn gợi ý đang mở.
  final Listenable? accessRevokedListenable;

  /// Trả `true` nếu quyền xem của người thân vừa bị thu hồi.
  final bool Function()? isAccessRevoked;

  /// Thông báo khi API trả 403 (`khong_co_quyen` / `consent_revoked`).
  final ValueChanged<MealSuggestionFailure>? onAccessDenied;

  @override
  State<MealSuggestionScreen> createState() => _MealSuggestionScreenState();
}

class _MealSuggestionScreenState extends State<MealSuggestionScreen> {
  final mascot = MascotController();
  late MealPlanController plan;
  late MealChoiceController choices;
  bool _booted = false;
  int _dir = 1;
  int? _celebrating;
  Timer? _autoNext, _celebrateTimer, _lookTimer;

  /// Đang mở màn chờ "Gợi ý khác": chặn bấm liên tục (mở 2 màn, gọi 2 lần) (AC9b).
  bool _opening = false;
  bool _reloadingConsent = false;
  bool _consentSyncedForCurrentFailure = false;
  MealSuggestionFailure? _deniedFailure;
  bool _unreportedAllergyReadOnly = false;
  bool _notifiedDenied = false;
  ModalRoute<dynamic>? _ownRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _ownRoute = ModalRoute.of(context);
    final scope = MealPlanScope.of(context);
    plan = scope.plan;
    choices = scope.choices;
    final user =
        widget.patientId ?? AuthScope.maybeOf(context)?.currentSession?.userId;
    plan.bind(user);
    unawaited(choices.bind(user));
    plan.addListener(_onPlan);
    widget.accessRevokedListenable?.addListener(_onExternalAccessChanged);
    if (widget.caregiverMode && (widget.isAccessRevoked?.call() ?? false)) {
      _deniedFailure = const MealSuggestionFailure(MealFailureKind.forbidden);
      plan.reset();
      plan.session.clear();
      unawaited(choices.clear());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    widget.accessRevokedListenable?.removeListener(_onExternalAccessChanged);
    plan.removeListener(_onPlan);
    _autoNext?.cancel();
    _celebrateTimer?.cancel();
    _lookTimer?.cancel();
    mascot.dispose();
    super.dispose();
  }

  bool _consentGranted(ConsentController c) =>
      c.isGranted(ConsentPurpose.aiMeal);

  bool _isAuthOrConsentFailure(MealFailureKind? kind) =>
      kind == MealFailureKind.consentRevoked ||
      kind == MealFailureKind.forbidden;

  MealSuggestionFailure? _firstAuthOrConsentFailure() {
    final all = <MealSuggestionFailure?>[
      plan.allergyFailure,
      plan.lastRefreshFailure,
      for (final t in MealType.values) plan.stateOf(t).failure,
    ];
    for (final f in all) {
      if (f != null && _isAuthOrConsentFailure(f.kind)) return f;
    }
    return null;
  }

  void _onExternalAccessChanged() {
    if (!mounted || !widget.caregiverMode) return;
    if (!(widget.isAccessRevoked?.call() ?? false)) return;
    _clearCaregiverState(
      const MealSuggestionFailure(MealFailureKind.forbidden),
      notifyExternal: false,
    );
    final route = _ownRoute;
    final nav = route?.navigator ?? Navigator.maybeOf(context);
    if (nav != null && route != null && !route.isFirst) {
      nav.popUntil((r) => r == route);
      if (nav.canPop()) nav.pop();
    }
  }

  void _clearCaregiverState(
    MealSuggestionFailure failure, {
    bool notifyExternal = true,
  }) {
    if (!mounted) return;
    _autoNext?.cancel();
    _celebrateTimer?.cancel();
    _lookTimer?.cancel();
    setState(() {
      _deniedFailure ??= failure;
      _opening = false;
    });
    plan.reset();
    plan.session.clear();
    unawaited(choices.clear());
    if (notifyExternal && !_notifiedDenied) {
      _notifiedDenied = true;
      widget.onAccessDenied?.call(failure);
    }
  }

  /// Server trả 403 dù app thấy đã đồng ý: chờ lượt phân tích kết thúc rồi tải lại consent;
  /// nếu `ai_meal` đã tắt thì xóa ngay thực đơn và món đã chọn trong phiên (AC2, AC6).
  /// Ở chế độ người thân (`caregiverMode`), xóa ngay bộ nhớ và chuyển sang trạng thái mất quyền (CD4).
  void _onPlan() {
    if (!mounted) return;
    if (widget.caregiverMode) {
      final failure = _firstAuthOrConsentFailure();
      if (failure != null) {
        _clearCaregiverState(failure);
      }
      return;
    }
    if (plan.isAnalyzing) {
      _consentSyncedForCurrentFailure = false;
      return;
    }
    final revoked = _isAuthOrConsentFailure(plan.lastRefreshFailure?.kind) ||
        MealType.values
            .any((t) => _isAuthOrConsentFailure(plan.stateOf(t).failure?.kind));
    if (!revoked) {
      _consentSyncedForCurrentFailure = false;
      return;
    }
    if (_reloadingConsent || _consentSyncedForCurrentFailure) return;
    _consentSyncedForCurrentFailure = true;
    unawaited(_reloadConsent());
  }

  Future<void> _reloadConsent() async {
    _reloadingConsent = true;
    try {
      final consent = ConsentScope.read(context);
      await consent.load();
      if (!mounted) return;
      if (!_consentGranted(consent)) {
        plan.reset();
        await choices.clear();
      }
    } finally {
      _reloadingConsent = false;
    }
  }

  Future<void> _boot() async {
    if (!mounted) return;
    if (widget.caregiverMode) {
      await _bootCaregiver();
      return;
    }
    final consent = ConsentScope.read(context);
    if (!consent.isLoaded) await consent.load();
    if (!mounted) return;
    if (plan.hasMenu && _consentGranted(consent)) {
      _show(widget.initialMeal ?? plan.tab);
      return;
    }
    if (plan.allergy == null && !plan.allergyLoading) {
      await plan.loadAllergy();
      if (!mounted) return;
    }
    final steps =
        missingMealSetup(consentGranted: _consentGranted(consent), plan: plan);
    if (steps.isNotEmpty) {
      final result = await showMealSetupSheet(context,
          plan: plan, consent: consent, steps: steps);
      if (!mounted) return;
      if (result == MealSetupResult.declareAllergy) {
        // Declare on the real health-profile step, then come back here and continue to the
        // menu without asking again (N7, AC12). Leaving without saving closes Dumi.
        final saved = await widget.onDeclareAllergy(context);
        if (!mounted) return;
        if (saved == true) {
          await plan.loadAllergy();
          return _boot();
        }
        Navigator.of(context).pop();
        return;
      }
      if (result != MealSetupResult.ready) {
        Navigator.of(context).pop();
        return;
      }
    }
    if (plan.hasMenu) {
      _show(widget.initialMeal ?? plan.tab);
      return;
    }
    final ok =
        await Navigator.of(context).push<bool>(AnalyzingView.route(plan));
    if (!mounted) return;
    if (ok == true && plan.hasMenu) {
      if (widget.initialMeal case final m?
          when plan.stateOf(m).status == MealTabStatus.data) {
        plan.selectTab(m);
      }
      _greet();
    } else if (!plan.hasMenu) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _bootCaregiver() async {
    if (!mounted) return;
    if (_deniedFailure != null || (widget.isAccessRevoked?.call() ?? false)) {
      _clearCaregiverState(
        _deniedFailure ?? const MealSuggestionFailure(MealFailureKind.forbidden),
        notifyExternal: _deniedFailure != null,
      );
      return;
    }
    if (plan.hasMenu) {
      _show(widget.initialMeal ?? plan.tab);
      return;
    }
    if (plan.allergy == null && !plan.allergyLoading) {
      await plan.loadAllergy();
      if (!mounted) return;
    }
    if (_deniedFailure != null) return;
    final allergyFailure = plan.allergyFailure;
    if (allergyFailure != null && _isAuthOrConsentFailure(allergyFailure.kind)) {
      _clearCaregiverState(allergyFailure);
      return;
    }
    if (!plan.allergyReported) {
      // QD-27 / QD-40: người thân chỉ xem, không khai báo dị ứng thay người bệnh.
      setState(() => _unreportedAllergyReadOnly = true);
      return;
    }
    if (!plan.dietaryDeclared) {
      plan.saveDietary(
          restrictions: const DietaryDeclaration.none(), preferences: const []);
    }
    final ok = await Navigator.of(context).push<bool>(AnalyzingView.route(
      plan,
      caregiverMode: true,
      patientName: _who(context),
      isAccessDenied: () =>
          _deniedFailure != null || (widget.isAccessRevoked?.call() ?? false),
    ));
    if (!mounted) return;
    if (_deniedFailure != null) return;
    if (ok == true && plan.hasMenu) {
      if (widget.initialMeal case final m?
          when plan.stateOf(m).status == MealTabStatus.data) {
        plan.selectTab(m);
      }
      _greet();
    } else if (!plan.hasMenu) {
      Navigator.of(context).maybePop();
    }
  }

  void _show(MealType meal) {
    plan.selectTab(meal);
    _greet();
  }

  void _greet() => mascot.play(MascotMood.wave);

  void _select(MealType m, {bool auto = false}) {
    if (!auto) _autoNext?.cancel();
    if (m == plan.tab) return;
    setState(() {
      _dir = m.index > plan.tab.index ? 1 : -1;
      _celebrating = null;
    });
    plan.selectTab(m);
    // Dumi liếc theo hướng chuyển bữa rồi nhìn lại người dùng
    mascot.lookAt(Offset(_dir * .9, 0));
    _lookTimer?.cancel();
    _lookTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) mascot.clearLook();
    });
  }

  Future<void> _choose(MealType m, MealSuggestionResult r, int index) async {
    if (widget.caregiverMode) return;
    if (choices.isChosen(m, r.suggestionId, index)) {
      await choices.unchoose(m); // bấm lại "Đã chọn" = bỏ chọn
      return;
    }
    final dish = r.dishes[index];
    final choice = MealChoice(
      name: dish.name,
      kcal: dish.kcalEstimate,
      suggestionId: r.suggestionId,
      dishIndex: index,
      imageId: dish.image?.imageId,
    );
    unawaited(
        choices.choose(m, choice).then((_) => _thumbnail(m, dish, choice)));
    unawaited(_maybeOfferWidget());
    HapticFeedback.mediumImpact();
    mascot.play(MascotMood.celebrate);
    setState(() => _celebrating = index);
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(const Duration(milliseconds: 1150), () {
      if (mounted) setState(() => _celebrating = null);
    });
    // Q8: tự sang bữa kế nếu bữa đó chưa chọn; bữa Tối thì ở lại.
    _autoNext?.cancel();
    final next = m.index + 1 < MealType.values.length
        ? MealType.values[m.index + 1]
        : null;
    if (next != null &&
        choices.choiceOf(next) == null &&
        plan.stateOf(next).status == MealTabStatus.data) {
      _autoNext = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) _select(next, auto: true);
      });
    }
  }

  /// Ảnh nhỏ 128 px cho widget màn hình chính; ảnh chưa sẵn thì widget dùng icon bữa.
  Future<void> _thumbnail(MealType m, MealDish dish, MealChoice choice) async {
    final image = plan.imageOf(dish);
    if (image == null || !image.isReady) return;
    try {
      final bytes = await plan.imageBytes(image);
      final png = await compute(mealThumbnailPng, bytes);
      if (png != null) await choices.attachThumbnail(m, choice, png);
    } on Exception catch (e) {
      debugPrint('meal thumbnail: $e'); // widget vẫn hiện tên món
    }
  }

  bool _offerWidget = false;

  /// Gợi ý một lần "Thêm widget ra màn hình chính" sau lần chọn món đầu tiên.
  Future<void> _maybeOfferWidget() async {
    if (_offerWidget) return;
    final offer = await choices.bridge.shouldOfferPin();
    if (offer && mounted) setState(() => _offerWidget = true);
  }

  void _closeWidgetHint({required bool add}) {
    setState(() => _offerWidget = false);
    unawaited(choices.bridge.markPinOffered());
    if (add) unawaited(choices.bridge.requestPin());
  }

  Future<void> _openDetail(
      MealType m, MealSuggestionResult r, int index) async {
    final toggled =
        await Navigator.of(context).push<bool>(MealDetailScreen.route(
      plan: plan,
      meal: m,
      result: r,
      index: index,
      chosen: !widget.caregiverMode && choices.isChosen(m, r.suggestionId, index),
      readOnly: widget.caregiverMode,
    ));
    if (toggled == true && mounted && !widget.caregiverMode) {
      await _choose(m, r, index);
    }
  }

  Future<void> _refresh() async {
    if (_opening) return;
    if (plan.refreshLocked) {
      await showRefreshLimitSheet(context);
      return;
    }
    _consentSyncedForCurrentFailure = false;
    setState(() => _opening = true);
    final meal = plan.tab;
    // "Gợi ý khác" chạy lại màn chờ cho riêng bữa đang xem (AC9).
    await Navigator.of(context).push<bool>(AnalyzingView.route(
      plan,
      refreshMeal: meal,
      caregiverMode: widget.caregiverMode,
      patientName: widget.caregiverMode ? _who(context) : null,
      isAccessDenied: widget.caregiverMode
          ? () =>
              _deniedFailure != null ||
              (widget.isAccessRevoked?.call() ?? false)
          : null,
    ));
    if (!mounted) return;
    setState(() => _opening = false);
    if (widget.caregiverMode && _deniedFailure != null) return;
    if (!plan.hasMenu) {
      Navigator.of(context).pop();
      return;
    }
    if (plan.lastRefreshFailure?.kind == MealFailureKind.refreshLimit) {
      await showRefreshLimitSheet(context); // server trả 429 (AC9b)
    }
  }

  String _who(BuildContext context) {
    if (widget.caregiverMode) {
      final name = widget.patientName?.trim();
      return (name == null || name.isEmpty) ? 'người thân' : name;
    }
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    final name = scope?.notifier?.profile?.fullName?.trim();
    return (name == null || name.isEmpty) ? 'bạn' : name;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (widget.caregiverMode && _deniedFailure != null) {
      return MealTypography(
        child: Scaffold(
          backgroundColor: MealColors.canvas,
          body: SafeArea(
            child: _deniedBody(context),
          ),
        ),
      );
    }
    if (widget.caregiverMode && _unreportedAllergyReadOnly) {
      final who = _who(context);
      return MealTypography(
        child: Scaffold(
          backgroundColor: MealColors.canvas,
          body: SafeArea(
            child: Padding(
              key: const ValueKey('fm-meal-unreported-allergy'),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RoundIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.info_outline_rounded,
                      size: 48, color: MealColors.brand),
                  const SizedBox(height: 16),
                  Text(
                    '$who chưa khai báo dị ứng thực phẩm',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MealColors.ink),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Người thân chỉ xem nên không thể khai báo dị ứng hoặc bật gợi ý thay người bệnh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: MealColors.ink2),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: MealColors.brand,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return MealTypography(
      child: Scaffold(
        backgroundColor: MealColors.canvas,
        body: ListenableBuilder(
          listenable: Listenable.merge([plan, choices]),
          builder: (context, _) {
            final meal = plan.tab;
            final state = plan.stateOf(meal);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  0, mq.padding.top + 8, 0, mq.padding.bottom + 28),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child: Text('Gợi ý bữa ăn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: MealColors.ink)),
                    ),
                    const SizedBox(width: 44),
                  ]),
                ),
                if (plan.hasMenu) ..._results(context, meal, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _deniedBody(BuildContext context) {
    final who = _who(context);
    if (_deniedFailure?.kind == MealFailureKind.consentRevoked) {
      return ListView(
        key: const ValueKey('meal-denied-view'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7FB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.shield_outlined,
                  size: 36, color: Color(0xFF5B3FA8)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$who chưa bật gợi ý bữa ăn',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: MealColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            '$who đã tắt hoặc chưa bật chia sẻ gợi ý bữa ăn.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: MealColors.ink2),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Dữ liệu đã xem trước đó đã được xóa khỏi bộ nhớ phiên.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: MealColors.ink2),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('lost-back'),
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF01554F),
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Quay lại'),
          ),
        ],
      );
    }
    return LostAccessView(
      key: const ValueKey('meal-denied-view'),
      name: who,
      signedIn: true,
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  List<Widget> _results(
      BuildContext context, MealType meal, MealTabState state) {
    final remaining = plan.refreshesRemaining ?? 0;
    final result = state.result;
    final patientLabel = widget.caregiverMode ? _who(context) : null;
    final effectiveDisclaimer = result == null
        ? kDefaultMealDisclaimer
        : (result.disclaimer.trim().isEmpty
            ? kDefaultMealDisclaimer
            : result.disclaimer);
    return [
      if (widget.caregiverMode) ...[
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey('fm-meal-readonly-chip'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  // Token R4 Figma (845:16996): pill chỉ xem #EDE7FB / #5B3FA8
                  color: const Color(0xFFEDE7FB),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_outline,
                    size: 16, color: Color(0xFF5B3FA8)),
                const SizedBox(width: 6),
                Text('$patientLabel · chỉ xem',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B3FA8))),
              ]),
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          SizedBox(
            width: 76,
            height: 76,
            child: MascotView(
                key: const ValueKey('results-mascot'),
                controller: mascot,
                outfit: MascotOutfit.chef,
                size: 76),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: MealGreeting(
              meal: meal,
              dir: _dir,
              who: _who(context),
              caregiverMode: widget.caregiverMode,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MealPillTabs(
          key: const ValueKey('meal-tabs'),
          labels: [for (final t in MealType.values) t.tabLabel],
          selected: meal.index,
          onChanged: (i) => _select(MealType.values[i]),
          badges: {
            for (final t in MealType.values)
              if (choices.choiceOf(t) != null)
                t.index: Icon(Icons.check_circle_rounded,
                    key: ValueKey('tab-chosen-${t.apiValue}'),
                    size: 16,
                    color: MealColors.teal)
              else if (plan.stateOf(t).status == MealTabStatus.error)
                t.index: Container(
                  key: ValueKey('tab-error-${t.apiValue}'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: MealColors.caution, shape: BoxShape.circle),
                ),
          },
        ),
      ),
      const SizedBox(height: 16),
      AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (c, a) {
          final incoming = c.key == ValueKey(meal);
          final dx = (incoming ? 1 : -1) * _dir * .18;
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position:
                  Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a),
              child: c,
            ),
          );
        },
        layoutBuilder: (cur, prev) => Stack(
            alignment: Alignment.topCenter,
            children: [...prev, if (cur != null) cur]),
        child: KeyedSubtree(key: ValueKey(meal), child: _mealBody(meal, state)),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (result != null && state.status == MealTabStatus.data) ...[
            _AvoidPanel(result.foodCheck, patientName: patientLabel),
            const SizedBox(height: 14),
            MealRefreshButton(
              busy: _opening,
              left: remaining,
              onTap: _refresh,
              onLocked: () => showRefreshLimitSheet(context),
            ),
            const SizedBox(height: 6),
            Text(
              remaining > 0
                  ? 'Còn $remaining lần gợi ý khác hôm nay'
                  : (widget.caregiverMode
                      ? 'Hôm nay đã dùng hết lượt gợi ý khác'
                      : 'Hôm nay bạn đã dùng hết lượt gợi ý khác'),
              key: const ValueKey('refresh-remaining'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: MealColors.ink2),
            ),
            if (_offerWidget && !widget.caregiverMode) ...[
              const SizedBox(height: 16),
              _WidgetHint(
                onAdd: () => _closeWidgetHint(add: true),
                onClose: () => _closeWidgetHint(add: false),
              ),
            ],
            const SizedBox(height: 16),
            MealDisclaimer(effectiveDisclaimer),
          ],
        ]),
      ),
    ];
  }

  Widget _mealBody(MealType m, MealTabState s) {
    if (s.status == MealTabStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _ErrorCard(
          meal: m,
          failure: s.failure!,
          onRetry: () => plan.retryMeal(m),
        ),
      );
    }
    final result = s.result;
    if (s.status != MealTabStatus.data || result == null) {
      return const SizedBox(
        height: 460,
        child:
            Center(child: CircularProgressIndicator(color: MealColors.brand)),
      );
    }
    final chosen = choices.choiceOf(m);
    return DishDeck(
      key: ValueKey('deck-${m.apiValue}-${result.suggestionId}'),
      meal: m,
      result: result,
      plan: plan,
      chosenIndex: !widget.caregiverMode &&
              chosen != null &&
              chosen.suggestionId == result.suggestionId
          ? chosen.dishIndex
          : null,
      celebratingIndex: widget.caregiverMode ? null : _celebrating,
      onChoose: (i) => _choose(m, result, i),
      onDetail: (i) => _openDetail(m, result, i),
      readOnly: widget.caregiverMode,
      patientName: widget.caregiverMode ? _who(context) : null,
    );
  }
}

/// "Nên tránh" thu gọn: kết quả 3 trạng thái của engine, bấm để mở (AC10).
class _AvoidPanel extends StatefulWidget {
  const _AvoidPanel(this.check, {this.patientName});
  final MealFoodCheck check;
  final String? patientName;
  @override
  State<_AvoidPanel> createState() => _AvoidPanelState();
}

class _AvoidPanelState extends State<_AvoidPanel> {
  bool _open = false;

  String get _summary => switch (widget.check.status) {
        FoodCheckStatus.coTuongTac =>
          '${widget.check.warnings.length} thực phẩm cần tránh với thuốc của ${widget.patientName ?? 'bạn'}',
        FoodCheckStatus.daKiemTraKhongThay =>
          'Chưa thấy tương tác trong dữ liệu hiện có',
        FoodCheckStatus.khongDuDuLieu => 'Chưa xác minh được, hãy hỏi dược sĩ',
      };

  @override
  Widget build(BuildContext context) {
    final warn = widget.check.status != FoodCheckStatus.daKiemTraKhongThay;
    final fg = widget.patientName != null
        ? (warn ? const Color(0xFF8A4B0F) : const Color(0xFF1E7A45))
        : (warn ? MealColors.caution : MealColors.teal);
    final badgeBg = widget.patientName != null
        ? (warn ? const Color(0xFFFFF4E5) : const Color(0xFFE3F4EA))
        : Colors.transparent;
    return Container(
      key: const ValueKey('avoid-panel'),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              Container(
                padding: widget.patientName != null
                    ? const EdgeInsets.all(6)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    warn
                        ? Icons.error_outline_rounded
                        : Icons.verified_user_rounded,
                    color: fg,
                    size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.patientName != null
                              ? '${widget.patientName} nên hạn chế'
                              : 'Nên tránh',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: widget.patientName != null && warn
                                  ? fg
                                  : MealColors.ink)),
                      Text(_summary,
                          style: TextStyle(
                              fontSize: 14,
                              color: widget.patientName != null && !warn
                                  ? fg
                                  : MealColors.ink2)),
                    ]),
              ),
              AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.expand_more_rounded,
                    color: MealColors.ink2),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: MealFoodCheckView(widget.check),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(
      {required this.meal, required this.failure, required this.onRetry});
  final MealType meal;
  final MealSuggestionFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 300),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: MealColors.caution),
          const SizedBox(height: 10),
          Text('Chưa có gợi ý cho ${meal.mealLabel}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MealColors.ink)),
          const SizedBox(height: 4),
          Text(failure.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: MealColors.ink2)),
          if (failure.canRetry) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: MealColors.brand,
                  shape: const StadiumBorder()),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ]),
      );
}

/// Thu ảnh món về PNG tròn 128 px cho widget (chạy trong isolate qua `compute`).
Uint8List? mealThumbnailPng(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  // Cắt tròn sẵn: RemoteViews của widget không tự bo ảnh trên Android cũ.
  return img.encodePng(
      img.copyCropCircle(img.copyResizeCropSquare(decoded, size: 128)));
}

class _WidgetHint extends StatelessWidget {
  const _WidgetHint({required this.onAdd, required this.onClose});
  final VoidCallback onAdd, onClose;

  @override
  Widget build(BuildContext context) => StaggerIn(
        index: 0,
        child: Container(
          key: const ValueKey('widget-hint'),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [MealColors.galaxyTop, MealColors.galaxyBottom]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Icon(Icons.widgets_rounded, color: MealColors.violet),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Thêm "Thực đơn hôm nay" ra màn hình chính để xem nhanh',
                style: TextStyle(
                    fontSize: 14,
                    color: MealColors.ink,
                    fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
                key: const ValueKey('widget-hint-add'),
                onPressed: onAdd,
                child: const Text('Thêm')),
            IconButton(
              tooltip: 'Đóng',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: MealColors.ink2),
            ),
          ]),
        ),
      );
}
