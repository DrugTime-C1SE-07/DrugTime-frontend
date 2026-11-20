import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../domain/entities/medication.dart';
import '../widgets/pill_appearance_icon.dart';

/// Kết quả kiểm tra tương tác thuốc–thuốc trước khi lưu, tóm tắt trên S07-M4. Giữ tách bốn
/// trường hợp (QD-37, bất biến 6): "chưa đủ dữ liệu" và "chưa kiểm tra được" không bao giờ
/// được hiện thành "không phát hiện".
enum InteractionOutcome {
  /// Đã kiểm tra, không thấy tương tác trong phạm vi dữ liệu hiện có.
  noneFound('Không phát hiện tương tác', LucideIcons.check),

  /// Có tương tác; người dùng đã xem cảnh báo và chọn vẫn thêm.
  acceptedWithInteractions('Có tương tác — bạn đã xác nhận', LucideIcons.triangleAlert),

  /// Thiếu dữ liệu hoạt chất để kết luận.
  insufficientData('Chưa đủ dữ liệu để kiểm tra', LucideIcons.circleHelp),

  /// Không gọi được kiểm tra (lỗi mạng, thuốc không có mã danh mục) mà người dùng vẫn thêm.
  notChecked('Chưa kiểm tra được tương tác', LucideIcons.circleHelp);

  const InteractionOutcome(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isSafe => this == InteractionOutcome.noneFound;
}

/// S07-M4 "Đã thêm thuốc!".
class MedicationAddedScreen extends StatefulWidget {
  const MedicationAddedScreen({
    super.key,
    required this.medication,
    required this.outcome,
    required this.addAnotherRoute,
  });

  final Medication medication;
  final InteractionOutcome outcome;

  /// Route mở lại luồng thêm thuốc ("Thêm thuốc khác"): màn quét hoặc màn nhập tay.
  final String addAnotherRoute;

  @override
  State<MedicationAddedScreen> createState() => _MedicationAddedScreenState();
}

class _MedicationAddedScreenState extends State<MedicationAddedScreen>
    with SingleTickerProviderStateMixin {
  /// Phóng to một lần khi mở màn; không lặp.
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = 1;
    } else if (_pop.value == 0 && !_pop.isAnimating) {
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  /// Cùng cách app.dart đưa về Trang chủ: dựng lại shell ở tab Trang chủ. Danh sách thuốc nằm
  /// ở controller cấp app nên không mất.
  void _goHome() => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);

  void _addAnother() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed(widget.addAnotherRoute);
  }

  String get _summary {
    final m = widget.medication;
    final often = m.frequency.isAsNeeded
        ? 'Khi cần'
        : '${m.times.isEmpty ? m.frequency.label : '${m.times.length} lần'} mỗi ngày';
    return '${m.name} · $often';
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    final m = widget.medication;
    final safe = outcome.isSafe;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const Spacer(),
              ScaleTransition(
                scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE7F3F1), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                        color: Color(0xFFD3EBE6), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(AppAssets.mascotHappy,
                        key: const Key('added-mascot'),
                        fit: BoxFit.contain,
                        excludeFromSemantics: true),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text('Đã thêm thuốc!',
                    style: AppTextStyles.display.copyWith(fontSize: 28)),
              ),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                PillAppearanceIcon(
                    shape: m.pillShape,
                    color: m.pillColor,
                    dosageForm: m.dosageForm,
                    size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_summary,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(color: AppColors.inkMuted)),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                key: const Key('interaction-outcome'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: safe ? const Color(0xFFE9F6EC) : AppColors.cautionBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(outcome.icon,
                      size: 18,
                      color: safe ? const Color(0xFF1E7B3A) : AppColors.cautionText),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(outcome.label,
                        style: AppTextStyles.bodyStrong.copyWith(
                            color: safe
                                ? const Color(0xFF1E7B3A)
                                : AppColors.cautionText)),
                  ),
                ]),
              ),
              const Spacer(flex: 2),
              FilledButton.icon(
                key: const Key('added-go-home'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.primaryButton)),
                onPressed: _goHome,
                icon: const Icon(LucideIcons.check),
                label: const Text('Về trang chủ'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                key: const Key('added-add-another'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.primaryButton)),
                onPressed: _addAnother,
                icon: const Icon(LucideIcons.plus),
                label: const Text('Thêm thuốc khác'),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}
