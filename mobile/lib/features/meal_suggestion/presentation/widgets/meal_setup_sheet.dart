import 'package:flutter/material.dart';

import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/domain/entities/consent_failure.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../state/meal_plan_controller.dart';
import 'dietary_sheet.dart';
import 'meal_ui.dart';

enum MealSetupStep { consent, dietary, allergy }

/// Các bước còn thiếu trước khi gợi ý, theo thứ tự hiện (01 mục B).
List<MealSetupStep> missingMealSetup(
        {required bool consentGranted, required MealPlanController plan}) =>
    [
      if (!consentGranted) MealSetupStep.consent,
      if (!plan.dietaryDeclared) MealSetupStep.dietary,
      if (!plan.allergyReported) MealSetupStep.allergy,
    ];

/// Kết quả sheet: `ready` thì vào màn chờ ngay; `declareAllergy` thì mở màn khai dị ứng.
enum MealSetupResult { ready, declareAllergy, cancelled }

/// Sheet "Dumi cần biết" thay 3 màn chặn: chỉ các bước còn thiếu, xong là vào màn chờ (AC1, AC2).
Future<MealSetupResult> showMealSetupSheet(
  BuildContext context, {
  required MealPlanController plan,
  required ConsentController consent,
  required List<MealSetupStep> steps,
}) async {
  final result = await showModalBottomSheet<MealSetupResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MealTypography(
      child: MealSetupSheet(plan: plan, consent: consent, steps: steps),
    ),
  );
  return result ?? MealSetupResult.cancelled;
}

class MealSetupSheet extends StatefulWidget {
  const MealSetupSheet({
    super.key,
    required this.plan,
    required this.consent,
    required this.steps,
  });

  final MealPlanController plan;
  final ConsentController consent;
  final List<MealSetupStep> steps;

  @override
  State<MealSetupSheet> createState() => _MealSetupSheetState();
}

class _MealSetupSheetState extends State<MealSetupSheet> {
  final mascot = MascotController();
  int _index = 0;
  bool _busy = false;
  String? _error;
  bool _unknownDietary = false;

  MealSetupStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    widget.plan.addListener(_onPlan);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => mascot.play(MascotMood.wave));
  }

  @override
  void dispose() {
    widget.plan.removeListener(_onPlan);
    mascot.dispose();
    super.dispose();
  }

  void _onPlan() {
    if (!mounted) return;
    setState(() {});
    // Hồ sơ dị ứng vừa tải xong và đã khai: bước dị ứng tự hoàn tất.
    if (_step == MealSetupStep.allergy && widget.plan.allergyReported) _next();
  }

  bool _closed = false;

  void _next() {
    if (_closed) return;
    if (_index >= widget.steps.length - 1) {
      _closed = true;
      Navigator.of(context).pop(MealSetupResult.ready);
      return;
    }
    setState(() {
      _index++;
      _error = null;
    });
    mascot.play(MascotMood.poke);
    if (_step == MealSetupStep.allergy && widget.plan.allergyReported) _next();
  }

  Future<void> _grant() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.consent.grant(ConsentPurpose.aiMeal);
      if (mounted) _next();
    } on ConsentFailure {
      if (mounted) setState(() => _error = 'Chưa bật được. Bạn thử lại nhé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _dietary(DietaryAnswer answer) {
    final restrictions = answer.restrictions;
    if (restrictions == null) {
      // "Chưa biết": không gọi API gợi ý (QD-40).
      setState(() => _unknownDietary = true);
      return;
    }
    widget.plan.saveDietary(
        restrictions: restrictions, preferences: answer.preferences);
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final total = widget.steps.length;
    return Container(
      key: const ValueKey('meal-setup-sheet'),
      constraints: BoxConstraints(maxHeight: mq.size.height * .9),
      padding: EdgeInsets.fromLTRB(
          22, 10, 22, 22 + mq.padding.bottom + mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                      color: MealColors.line,
                      borderRadius: BorderRadius.circular(4))),
            ),
            Row(children: [
              SizedBox(
                width: 90,
                height: 90,
                child: MascotView(
                    controller: mascot, outfit: MascotOutfit.chef, size: 90),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dumi cần biết',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: MealColors.ink)),
                      Text('Bước ${_index + 1}/$total · chỉ hỏi một lần',
                          style: const TextStyle(
                              fontSize: 14, color: MealColors.ink2)),
                    ]),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (_index + 1) / total),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: MealColors.teal,
                    backgroundColor: MealColors.chip),
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position:
                          Tween(begin: const Offset(.12, 0), end: Offset.zero)
                              .animate(a),
                      child: c),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _body()),
              ),
            ),
          ]),
    );
  }

  Widget _primary(String label, VoidCallback? onTap, {Key? key}) => SizedBox(
        height: 54,
        child: FilledButton(
          key: key,
          style: FilledButton.styleFrom(
              backgroundColor: MealColors.brand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _body() {
    switch (_step) {
      case MealSetupStep.consent:
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dumi dùng tên hoạt chất, bệnh nền, dị ứng và hạn chế ăn uống của bạn '
                '(không kèm thông tin định danh) để gợi ý món. Bạn tắt được bất cứ lúc nào '
                'trong Quyền riêng tư.',
                style: TextStyle(
                    fontSize: 15, height: 1.45, color: MealColors.ink),
              ),
              if (_error case final e?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(e,
                      style: const TextStyle(
                          fontSize: 14, color: MealColors.danger)),
                ),
              const SizedBox(height: 18),
              _primary('Bật gợi ý bữa ăn', _busy ? null : _grant,
                  key: const ValueKey('grant-ai-meal')),
            ]);
      case MealSetupStep.dietary:
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: DietarySheet(
                  session: widget.plan.session,
                  showTitle: false,
                  onSubmit: _dietary,
                ),
              ),
              if (_unknownDietary)
                const Text(
                  'Dumi chưa gợi ý khi chưa rõ hạn chế ăn uống. Bạn khai khi đã rõ nhé.',
                  key: ValueKey('dietary-unknown-note'),
                  style: TextStyle(fontSize: 14, color: MealColors.ink2),
                ),
            ]);
      case MealSetupStep.allergy:
        final plan = widget.plan;
        if (plan.allergyFailed) {
          return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Chưa đọc được hồ sơ dị ứng. Bạn thử lại nhé.',
                    style: TextStyle(fontSize: 15, color: MealColors.ink)),
                const SizedBox(height: 18),
                _primary('Thử lại', plan.loadAllergy,
                    key: const ValueKey('allergy-retry')),
              ]);
        }
        if (plan.allergy == null || plan.allergyLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: MealColors.brand)),
          );
        }
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Dị ứng thực phẩm',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: MealColors.ink)),
              const SizedBox(height: 8),
              const Text(
                  'Dumi cần biết bạn có dị ứng thực phẩm nào không trước khi gợi ý món.',
                  style: TextStyle(fontSize: 15, color: MealColors.ink)),
              const SizedBox(height: 18),
              _primary(
                'Khai dị ứng',
                () => Navigator.of(context).pop(MealSetupResult.declareAllergy),
                key: const ValueKey('declare-allergy'),
              ),
            ]);
    }
  }
}
