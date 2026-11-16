import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/domain/entities/consent_failure.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../../../profile/presentation/state/profile_controller.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/allergy_profile_repository.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';
import '../state/meal_suggestion_controller.dart';
import '../widgets/dietary_sheet.dart';
import '../widgets/meal_widgets.dart';
import 'meal_detail_screens.dart';

/// Màn gợi ý bữa ăn (S05-D, S05-D2; task 5.11). Mở từ nút "Dumi AI" ở Trang chủ.
class MealSuggestionScreen extends StatefulWidget {
  const MealSuggestionScreen({
    super.key,
    required this.repository,
    required this.allergyRepository,
    required this.onDeclareAllergy,
    this.patientId,
    this.controllerFactory,
  });

  final MealSuggestionRepository repository;
  final AllergyProfileRepository allergyRepository;

  /// Mở màn khai dị ứng (router truyền vào; màn đó làm sau, 01 mục A).
  final void Function(BuildContext context) onDeclareAllergy;

  /// Mặc định là người dùng đang đăng nhập (gợi ý chỉ cho chính chủ, AC17).
  final String? patientId;

  /// Cho test: dựng controller với đồng hồ / nhịp hỏi ảnh riêng.
  final MealSuggestionController Function(String patientId)? controllerFactory;

  @override
  State<MealSuggestionScreen> createState() => _MealSuggestionScreenState();
}

class _MealSuggestionScreenState extends State<MealSuggestionScreen> {
  MealSuggestionController? _controller;
  bool _granting = false;
  String? _consentError;

  MealSuggestionController get controller => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final patientId = widget.patientId ??
        AuthScope.read(context).currentSession?.userId ??
        '';
    _controller = widget.controllerFactory?.call(patientId) ??
        MealSuggestionController(
          repository: widget.repository,
          allergyRepository: widget.allergyRepository,
          patientId: patientId,
        );
    controller.addListener(_onControllerChanged);
    final consent = ConsentScope.read(context);
    if (!consent.isLoaded && !consent.isLoading) unawaited(consent.load());
    unawaited(controller.loadAllergy().then((_) => _maybeLoad()));
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  bool get _consentGranted =>
      ConsentScope.read(context).isGranted(ConsentPurpose.aiMeal);

  /// Server trả 403 dù app thấy đã đồng ý: tải lại consent, không hiện gợi ý (AC2).
  void _onControllerChanged() {
    final kind = controller.current.failure?.kind;
    if (kind == MealFailureKind.consentRevoked ||
        kind == MealFailureKind.forbidden) {
      unawaited(ConsentScope.read(context).load());
    }
  }

  void _maybeLoad() {
    if (!mounted || !_consentGranted || !controller.canRequest) return;
    if (controller.current.status == MealTabStatus.idle) {
      unawaited(controller.load(controller.tab));
    }
  }

  Future<void> _grant() async {
    setState(() {
      _granting = true;
      _consentError = null;
    });
    try {
      await ConsentScope.read(context).grant(ConsentPurpose.aiMeal);
      _maybeLoad();
    } on ConsentFailure {
      _consentError = 'Chưa bật được. Bạn thử lại nhé.';
    } finally {
      if (mounted) setState(() => _granting = false);
    }
  }

  Future<void> _askDietary() async {
    final answer = await showDietarySheet(context, session: controller.session);
    if (!mounted || answer == null) return;
    final restrictions = answer.restrictions;
    if (restrictions == null) return; // "Chưa biết": không gọi API (QD-40)
    controller.saveDietary(
        restrictions: restrictions, preferences: answer.preferences);
    _maybeLoad();
  }

  @override
  Widget build(BuildContext context) {
    final consent = ConsentScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Gợi ý bữa ăn')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            _Greeting(type: controller.tab),
            const SizedBox(height: AppSpacing.md),
            _MealTabs(
              selected: controller.tab,
              onSelected: (t) {
                controller.selectTab(t);
                _maybeLoad();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._body(consent),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(ConsentController consent) {
    if (!consent.isGranted(ConsentPurpose.aiMeal)) {
      if (consent.isLoading && !consent.isLoaded) return const [_Loading()];
      return [
        _Notice(
          icon: LucideIcons.sparkles,
          title: 'Bật gợi ý bữa ăn',
          text: 'Dumi dùng tên hoạt chất, bệnh nền, dị ứng và hạn chế ăn uống của bạn '
              '(không kèm thông tin định danh) để gợi ý món. Bạn tắt được bất cứ lúc nào '
              'trong Quyền riêng tư.',
          action: FilledButton(
            key: const ValueKey('grant-ai-meal'),
            onPressed: _granting ? null : _grant,
            child: const Text('Bật gợi ý bữa ăn'),
          ),
          footer: _consentError,
        ),
      ];
    }
    if (controller.allergyLoading || controller.allergy == null) {
      if (controller.allergyFailed) {
        return [
          _Notice(
            icon: LucideIcons.circleAlert,
            title: 'Chưa đọc được hồ sơ dị ứng',
            text: 'Bạn thử lại nhé.',
            action: OutlinedButton(
              onPressed: () =>
                  controller.loadAllergy().then((_) => _maybeLoad()),
              child: const Text('Thử lại'),
            ),
          ),
        ];
      }
      return const [_Loading()];
    }
    if (!controller.allergyReported) {
      return [
        _Notice(
          icon: LucideIcons.shieldAlert,
          title: 'Bạn chưa khai dị ứng',
          text: 'Dumi cần biết bạn có dị ứng thực phẩm nào không trước khi gợi ý món.',
          action: FilledButton(
            key: const ValueKey('declare-allergy'),
            onPressed: () => widget.onDeclareAllergy(context),
            child: const Text('Khai dị ứng'),
          ),
        ),
      ];
    }
    if (!controller.dietaryDeclared) {
      return [
        _Notice(
          icon: LucideIcons.utensils,
          title: 'Bạn có hạn chế ăn uống không?',
          text: 'Khai một lần cho cả phiên dùng app.',
          action: FilledButton(
            key: const ValueKey('declare-dietary'),
            onPressed: _askDietary,
            child: const Text('Khai hạn chế ăn uống'),
          ),
        ),
      ];
    }
    final state = controller.current;
    switch (state.status) {
      case MealTabStatus.idle:
      case MealTabStatus.loading:
        return const [_Loading(text: 'Dumi đang chọn món cho bạn…')];
      case MealTabStatus.error:
        final failure = state.failure!;
        return [
          _Notice(
            icon: LucideIcons.circleAlert,
            title: 'Chưa có gợi ý',
            text: failure.message,
            action: failure.canRetry
                ? OutlinedButton(
                    key: const ValueKey('retry'),
                    onPressed: () => controller.load(controller.tab),
                    child: const Text('Thử lại'),
                  )
                : null,
          ),
        ];
      case MealTabStatus.data:
        return _data(state);
    }
  }

  List<Widget> _data(MealTabState state) {
    final result = state.result!;
    final main = state.mainDish!;
    final remaining = controller.refreshesRemaining ?? 0;
    return [
      _MainCard(
        dish: main,
        controller: controller,
        canRotate: result.dishes.length > 1,
        onDetail: () => _openDetail(main, result),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (state.otherIndexes.isNotEmpty) ...[
        Row(children: [
          Expanded(
            child: Text('Món khác cho ${result.mealType.mealLabel}',
                style: AppTextStyles.heading),
          ),
          TextButton(
            key: const ValueKey('see-all'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  MealListScreen(controller: controller, result: result),
            )),
            child: const Text('Xem tất cả'),
          ),
        ]),
        SizedBox(
          height: 190,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final i in state.otherIndexes)
                _OtherDishCard(
                  dish: result.dishes[i],
                  controller: controller,
                  isPreviousMain: i == state.previousMainIndex,
                  onTap: () => controller.promote(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      const Text('Nên tránh', style: AppTextStyles.heading),
      const SizedBox(height: AppSpacing.sm),
      MealFoodCheckView(result.foodCheck),
      const SizedBox(height: AppSpacing.lg),
      OutlinedButton.icon(
        key: const ValueKey('refresh'),
        icon: state.refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(LucideIcons.refreshCw),
        label: const Text('Gợi ý khác'),
        onPressed: controller.canRefresh ? controller.refresh : null,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        remaining > 0
            ? 'Còn $remaining lần gợi ý khác hôm nay'
            : 'Hôm nay bạn đã dùng hết lượt gợi ý khác',
        key: const ValueKey('refresh-remaining'),
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      ),
      if (state.refreshFailure case final f?
          when f.kind != MealFailureKind.refreshLimit)
        Text(f.message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
      const SizedBox(height: AppSpacing.lg),
      MealDisclaimer(result.disclaimer),
    ];
  }

  void _openDetail(MealDish dish, MealSuggestionResult result) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          MealDetailScreen(controller: controller, dish: dish, result: result),
    ));
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.type});

  final MealType type;

  @override
  Widget build(BuildContext context) {
    final profile =
        context.dependOnInheritedWidgetOfExactType<ProfileScope>()?.notifier;
    final name = profile?.profile?.fullName?.trim();
    final who = (name == null || name.isEmpty) ? 'bạn' : name;
    return Row(children: [
      Image.asset(AppAssets.mascotCooking,
          height: 48,
          errorBuilder: (_, __, ___) =>
              const Icon(LucideIcons.cookingPot, color: AppColors.brand)),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text('${type.todayLabel} ăn gì, $who?',
            style: AppTextStyles.heading),
      ),
    ]);
  }
}

class _MealTabs extends StatelessWidget {
  const _MealTabs({required this.selected, required this.onSelected});

  final MealType selected;
  final ValueChanged<MealType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MealType>(
      showSelectedIcon: false,
      segments: [
        for (final t in MealType.values)
          ButtonSegment(value: t, label: Text(t.tabLabel)),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onSelected(s.single),
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.dish,
    required this.controller,
    required this.canRotate,
    required this.onDetail,
  });

  final MealDish dish;
  final MealSuggestionController controller;
  final bool canRotate;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('main-card'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.cardElevation,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          MealImageView(
              image: controller.imageOf(dish),
              loadBytes: controller.imageBytes,
              height: 190),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.sparkles, size: 14, color: AppColors.caution),
                SizedBox(width: 4),
                Text('Dumi chọn', style: AppTextStyles.captionStrong),
              ]),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(dish.name,
                      key: const ValueKey('main-dish-name'),
                      style: AppTextStyles.title)),
              if (canRotate)
                TextButton.icon(
                  key: const ValueKey('rotate'),
                  icon: const Icon(LucideIcons.rotateCcw, size: 18),
                  label: const Text('Đổi món'),
                  onPressed: controller.rotate,
                ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              for (final tag in dish.tags) MealChip(tag),
              MealChip('${kcalLabel(dish.kcalEstimate)}/phần'),
            ]),
            const SizedBox(height: AppSpacing.sm),
            const Text('Gợi ý dựa trên danh sách thuốc của bạn',
                style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('detail'),
                onPressed: onDetail,
                child: const Text('Chi tiết'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _OtherDishCard extends StatelessWidget {
  const _OtherDishCard({
    required this.dish,
    required this.controller,
    required this.isPreviousMain,
    required this.onTap,
  });

  final MealDish dish;
  final MealSuggestionController controller;
  final bool isPreviousMain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            MealImageView(
                image: controller.imageOf(dish),
                loadBytes: controller.imageBytes,
                height: 100,
                showAttribution: false),
            Positioned(
                left: 6, bottom: 6, child: MealChip(kcalLabel(dish.kcalEstimate))),
            if (isPreviousMain)
              const Positioned(
                right: 6,
                bottom: 6,
                child: CircleAvatar(
                  key: ValueKey('undo-previous-main'),
                  radius: 14,
                  backgroundColor: AppColors.brand,
                  child: Icon(LucideIcons.undo2, size: 16, color: AppColors.onBrand),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(dish.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong),
          ),
        ]),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.xs),
        Text(text, style: AppTextStyles.body),
        if (action case final a?) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(width: double.infinity, child: a),
        ],
        if (footer case final f?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(f,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
          ),
      ]),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(children: [
          const CircularProgressIndicator(),
          if (text case final t?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(t, style: AppTextStyles.caption),
          ],
        ]),
      );
}
