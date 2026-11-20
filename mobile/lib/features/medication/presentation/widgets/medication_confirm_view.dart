import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import 'medication_labels.dart';
import 'pill_appearance_icon.dart';

// ---------------------------------------------------------------------------------------------
// Khung dùng chung của các màn thêm thuốc (S07-M2, M2b, M3) theo mockup "Thêm thuốc bước 3".
// ---------------------------------------------------------------------------------------------

abstract final class AddFlowColors {
  static const background = Color(0xFFF4F6F5);
  static const track = Color(0xFFE1E5E3);
  static const chip = Color(0xFFE4F2EF);
}

/// App bar có nút quay lại dạng tròn như mockup.
PreferredSizeWidget addFlowAppBar(BuildContext context, String title) => AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: AddFlowColors.background,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: IconButton.filled(
          tooltip: 'Quay lại',
          style: IconButton.styleFrom(
              backgroundColor: AddFlowColors.chip, foregroundColor: AppColors.brand),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.chevronLeft),
        ),
      ),
    );

/// "Bước n/3 · …" và 3 vạch tiến trình.
class AddFlowProgress extends StatelessWidget {
  const AddFlowProgress({super.key, required this.step, required this.label});

  /// 1..3
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.brand, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: i < step ? AppColors.brand : AddFlowColors.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ]),
        ]),
      );
}

/// Thanh nút cố định ở đáy màn.
class AddFlowBottomBar extends StatelessWidget {
  const AddFlowBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: children),
          ),
        ),
      );
}

/// Thẻ thuốc ở đầu các bước 2 và 3: icon, tên, dòng phụ, nút (i) mở "Thông tin thuốc" và một
/// nút hành động ("Đổi").
class AddFlowDrugCard extends StatelessWidget {
  const AddFlowDrugCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onInfo,
    this.dosageForm,
    this.shape,
    this.color,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  final String name;
  final String subtitle;
  final String? dosageForm;
  final PillShape? shape;
  final PillColor? color;
  final VoidCallback onInfo;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          PillAppearanceTile(shape: shape, color: color, dosageForm: dosageForm),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: AppTextStyles.bodyStrong),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
            ]),
          ),
          IconButton(
            key: const Key('drug-info-button'),
            tooltip: 'Xem thông tin thuốc',
            onPressed: onInfo,
            icon: const Icon(LucideIcons.info, color: AppColors.brand),
          ),
          if (actionLabel != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(
                  backgroundColor: AddFlowColors.chip,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(actionLabel!),
            ),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------
// S07-M3 · Xác nhận
// ---------------------------------------------------------------------------------------------

/// S07-M3: người bệnh rà lại tên thuốc, hàm lượng, đơn vị, liều và giờ trước khi tạo lịch
/// (QD-39). Dùng chung cho luồng quét và luồng tìm tay.
class MedicationConfirmView extends StatelessWidget {
  const MedicationConfirmView({
    super.key,
    required this.drug,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.timing,
    required this.maxDoses,
    required this.onInfo,
    required this.onChangeAppearance,
    this.shape,
    this.color,
    this.inUse = false,
  });

  final DrugCatalogItem drug;
  final double dose;
  final DoseFrequency frequency;
  final List<DoseTime> times;
  final IntakeTiming timing;
  final int maxDoses;
  final PillShape? shape;
  final PillColor? color;
  final bool inUse;
  final VoidCallback onInfo;
  final VoidCallback onChangeAppearance;

  String get _unit => drug.unit.isEmpty ? 'viên' : drug.unit;

  /// "Viên nang · cam"; chưa chọn thì "500 mg · Viên nén".
  String get _subtitle {
    if (shape == null && color == null) {
      return strengthAndForm(drug.strength, drug.dosageForm);
    }
    final s = shape ?? PillShape.suggestFor(drug.dosageForm);
    return [s.label, if (color != null) color!.label.toLowerCase()].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final asNeeded = frequency.isAsNeeded;
    final sortedTimes = [...times]..sort();
    final perDay = asNeeded ? null : dose * sortedTimes.length;
    final rows = <(String, String)>[
      ('Hàm lượng',
          drug.strength.trim().isEmpty ? 'Chưa có thông tin' : formatStrength(drug.strength)),
      ('Mỗi lần', '${formatQuantity(dose)} $_unit'),
      (
        'Giờ uống',
        asNeeded
            ? 'Khi cần · tối đa $maxDoses lần/ngày'
            : sortedTimes.map((t) => t.format()).join(' · ')
      ),
      ('Uống khi nào', timing == IntakeTiming.anytime ? 'Bất kỳ' : timing.label),
      (
        'Tổng mỗi ngày',
        asNeeded
            ? 'Tối đa ${formatQuantity(dose * maxDoses)} $_unit'
            : '${formatQuantity(perDay!)} $_unit'
      ),
    ];

    return ListView(
      key: const Key('medication-confirm-view'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        const AddFlowProgress(step: 3, label: 'Bước 3/3 · Xác nhận'),
        const SizedBox(height: 20),
        AddFlowDrugCard(
          name: drug.name,
          subtitle: _subtitle,
          dosageForm: drug.dosageForm,
          shape: shape,
          color: color,
          onInfo: onInfo,
          actionLabel: 'Đổi',
          actionKey: const Key('change-pill-appearance'),
          onAction: onChangeAppearance,
        ),
        if (inUse) ...[
          const SizedBox(height: 8),
          Text('${drug.name} đã có trong danh sách đang dùng. '
              'Kiểm tra lại để tránh uống trùng liều.',
              style: AppTextStyles.body.copyWith(color: AppColors.cautionText)),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            for (final (i, (label, value)) in rows.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Semantics(
                  container: true,
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: Row(children: [
                    Expanded(
                      child: Text(label,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.inkMuted)),
                    ),
                    Flexible(
                      flex: 2,
                      child: Text(value,
                          textAlign: TextAlign.end,
                          style: AppTextStyles.bodyStrong),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.shield, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'DrugTime kiểm tra tương tác với các thuốc bạn đang dùng trước khi thêm.',
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
