import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import 'dosage_form_icon.dart';
import 'medication_labels.dart';

/// Nhãn một trường nhập, kèm dòng gợi ý phía dưới nếu có.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text.rich(
        TextSpan(
          text: text,
          style: AppTextStyles.bodyStrong,
          children: [
            if (optional)
              const TextSpan(
                  text: '  (không bắt buộc)', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class FormHelperText extends StatelessWidget {
  const FormHelperText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.caption),
    );
  }
}

class ScanEntryCard extends StatelessWidget {
  const ScanEntryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandTint,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: AppSizes.tapTarget,
                height: AppSizes.tapTarget,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.document_scanner_outlined,
                    color: AppColors.brand),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quét vỏ thuốc', style: AppTextStyles.bodyStrong),
                    SizedBox(height: 2),
                    Text(
                      'Dùng camera để tự điền tên và hàm lượng',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(label,
                textAlign: TextAlign.center, style: AppTextStyles.caption),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

/// Ô chọn thuốc từ danh mục. Khi đã chọn thì hiện tên + hoạt chất để người dùng
/// nhìn lại được mình đã chọn đúng thuốc chưa.
class DrugPickerField extends StatelessWidget {
  const DrugPickerField({
    super.key,
    required this.value,
    required this.onTap,
    this.onInfo,
    this.errorText,
  });

  final DrugCatalogItem? value;
  final VoidCallback onTap;
  final VoidCallback? onInfo;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final drug = value;
    final hasError = errorText != null;
    final radius = BorderRadius.circular(AppRadius.field);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: drug == null
              ? 'Chọn thuốc từ danh mục'
              : 'Thuốc đã chọn: ${drug.name}. Nhấn để đổi',
          excludeSemantics: true,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: hasError ? AppColors.danger : AppColors.border,
                width: hasError ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.field),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: drug == null
                      ? const _PickerPlaceholder()
                      : _PickedDrug(drug, onInfo: onInfo),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppTextStyles.captionStrong
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PickerPlaceholder extends StatelessWidget {
  const _PickerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.search, color: AppColors.inkMuted),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Tìm tên thuốc, hoạt chất…',
            style: TextStyle(fontSize: 16, color: AppColors.inkMuted),
          ),
        ),
        Icon(Icons.chevron_right, color: AppColors.inkMuted),
      ],
    );
  }
}

class _PickedDrug extends StatelessWidget {
  const _PickedDrug(this.drug, {this.onInfo});

  final DrugCatalogItem drug;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DosageFormTile(dosageForm: drug.dosageForm, size: 40),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(drug.name, style: AppTextStyles.bodyStrong),
              Text(
                drugSubtitle(drug.activeIngredient, drug.dosageForm),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        if (onInfo != null)
          IconButton(
            icon: const Icon(Icons.info_outline,
                color: AppColors.brand, size: 22),
            onPressed: onInfo,
            tooltip: 'Xem thông tin thuốc',
          ),
        const SizedBox(width: AppSpacing.xs),
        Text('Đổi',
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.brand)),
      ],
    );
  }
}

/// Ô chỉ đọc (giá trị tự điền từ danh mục), nền xám + ổ khoá để phân biệt
/// với ô nhập được.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField(
      {super.key, required this.value, required this.placeholder});

  final String? value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.field),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              v ?? placeholder,
              style: v == null
                  ? AppTextStyles.body.copyWith(color: AppColors.inkMuted)
                  : AppTextStyles.figure,
            ),
          ),
          const Icon(Icons.lock_outline, size: 18, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

/// Bộ tăng/giảm theo bước 1 (liều mỗi lần, số lần tối đa mỗi ngày). Dùng stepper thay cho
/// ô gõ chữ để tránh nhập sai số. Giá trị có thể lẻ (liều 0,5 viên do server trả về).
class DoseStepper extends StatelessWidget {
  const DoseStepper({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.decreaseTooltip = 'Giảm liều',
    this.increaseTooltip = 'Tăng liều',
  });

  final double value;
  final String unit;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String decreaseTooltip;
  final String increaseTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: decreaseTooltip,
            onPressed: value - 1 >= min ? () => onChanged(value - 1) : null,
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '${formatQuantity(value)} $unit',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.figure,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: increaseTooltip,
            onPressed: value + 1 <= max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton(
      {required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppSizes.tapTarget),
        backgroundColor: AppColors.brandTint,
        foregroundColor: AppColors.brand,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.inkDisabled,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm)),
      ),
    );
  }
}

/// Ô giờ uống cho lần thứ [index] trong ngày; nhấn để đổi giờ.
class DoseTimeTile extends StatelessWidget {
  const DoseTimeTile({
    super.key,
    required this.index,
    required this.time,
    required this.onTap,
  });

  final int index;
  final DoseTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.field);
    return Semantics(
      button: true,
      label: 'Lần ${index + 1}, uống lúc ${time.format()}. Nhấn để đổi giờ',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lần ${index + 1}', style: AppTextStyles.caption),
                      Text(time.format(), style: AppTextStyles.figure),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined,
                    size: 20, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chọn cách uống so với bữa ăn — danh sách radio lớn, dễ bấm, dễ đọc.
class IntakeTimingSelector extends StatelessWidget {
  const IntakeTimingSelector(
      {super.key, required this.value, required this.onChanged});

  final IntakeTiming value;
  final ValueChanged<IntakeTiming> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, option) in IntakeTiming.values.indexed) ...[
            if (i > 0) const Divider(height: 1),
            _RadioRow(
              label: option.label,
              selected: option == value,
              onTap: () => onChanged(option),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.brandTint : AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? AppColors.brand : AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: selected
                          ? AppTextStyles.bodyStrong
                          : AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghi chú trung tính (nền xám + icon), dùng cho thông tin không khẩn cấp.
class InfoNote extends StatelessWidget {
  const InfoNote(
      {super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.caption.copyWith(color: AppColors.ink))),
        ],
      ),
    );
  }
}

/// Cảnh báo mức "chú ý" (màu cam + icon + chữ).
class CautionNote extends StatelessWidget {
  const CautionNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.cautionText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.cautionText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ hiển thị tóm tắt thuốc đã chọn ở Bước 2 & 3.
class SelectedDrugCard extends StatelessWidget {
  const SelectedDrugCard({
    super.key,
    required this.drug,
    this.onChange,
  });

  final DrugCatalogItem drug;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DosageFormTile(dosageForm: drug.dosageForm, size: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(drug.name, style: AppTextStyles.bodyStrong),
                if (drug.strength.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Hàm lượng: ${drug.strength}',
                      style: AppTextStyles.caption),
                ],
                if (drug.activeIngredient.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Hoạt chất: ${drug.activeIngredient}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.inkMuted)),
                ],
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              child: const Text('Đổi'),
            ),
        ],
      ),
    );
  }
}

/// Item kết quả tìm kiếm thuốc theo Figma S07-M1 (Node 452:1683).
class FigmaDrugResultTile extends StatelessWidget {
  const FigmaDrugResultTile({
    super.key,
    required this.item,
    required this.onTap,
    this.isInUse = false,
  });

  final DrugCatalogItem item;
  final VoidCallback onTap;
  final bool isInUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                DosageFormTile(dosageForm: item.dosageForm, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: 3),
                      Text(
                        item.activeIngredient.isNotEmpty
                            ? '${item.activeIngredient} · ${item.dosageForm ?? "Viên"}'
                            : (item.dosageForm ?? item.strength),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isInUse)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Đang dùng',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.cautionText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút "Quét vỏ hộp để tự điền" theo Figma S07-M1 (Node 492:7599).
class FigmaScanOcrButton extends StatelessWidget {
  const FigmaScanOcrButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandTint,
          foregroundColor: AppColors.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.document_scanner_outlined, size: 22),
              SizedBox(width: 8),
              Text(
                'Quét vỏ thuốc',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card thông tin thuốc đã chọn theo Figma S07-M2 (Node 492:7816).
class FigmaDrugCard extends StatelessWidget {
  const FigmaDrugCard({
    super.key,
    required this.drug,
    this.onChange,
  });

  final DrugCatalogItem drug;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          DosageFormTile(dosageForm: drug.dosageForm, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(drug.name, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  drug.activeIngredient.isNotEmpty
                      ? '${drug.activeIngredient} · ${drug.dosageForm ?? "Viên"}'
                      : (drug.dosageForm ?? drug.strength),
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.brandTint,
                foregroundColor: AppColors.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Đổi',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Card thiết lập lịch uống theo chuẩn Figma S07-M2 (Node 492:7836).
class FigmaScheduleCard extends StatelessWidget {
  const FigmaScheduleCard({
    super.key,
    required this.dose,
    required this.unit,
    required this.times,
    required this.timing,
    required this.onDoseChanged,
    required this.onAddTime,
    required this.onRemoveTime,
    required this.onTimingChanged,
  });

  final double dose;
  final String unit;
  final List<DoseTime> times;
  final IntakeTiming timing;
  final ValueChanged<double> onDoseChanged;
  final VoidCallback onAddTime;
  final ValueChanged<int> onRemoveTime;
  final ValueChanged<IntakeTiming> onTimingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mỗi lần uống stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mỗi lần uống', style: AppTextStyles.bodyStrong),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20),
                      onPressed: dose > 0.5
                          ? () => onDoseChanged(dose - 1 < 0.5 ? 0.5 : dose - 1)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${formatQuantity(dose)} $unit',
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => onDoseChanged(dose + 1),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.dividerSoft),

          // Giờ uống
          const Text('Giờ uống', style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < times.length; i++)
                Chip(
                  label: Text(times[i].format(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.brandTint,
                  labelStyle: const TextStyle(color: AppColors.brand),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  deleteIcon: times.length > 1
                      ? const Icon(Icons.close,
                          size: 16, color: AppColors.brand)
                      : null,
                  onDeleted: times.length > 1 ? () => onRemoveTime(i) : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18, color: AppColors.brand),
                label: const Text('+ Thêm giờ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.brand)),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: onAddTime,
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.dividerSoft),

          // Uống khi nào
          const Text('Uống khi nào', style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final t in [
                IntakeTiming.beforeMeal,
                IntakeTiming.afterMeal,
                IntakeTiming.anytime
              ]) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          t == IntakeTiming.anytime ? 'Bất kỳ' : t.label,
                          style: TextStyle(
                            color:
                                timing == t ? AppColors.onBrand : AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      selected: timing == t,
                      onSelected: (selected) {
                        if (selected) onTimingChanged(t);
                      },
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: timing == t ? AppColors.brand : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Thẻ tóm tắt toàn bộ thông tin liều và lịch uống ở Bước 3: Xác nhận.
class ScheduleSummaryCard extends StatelessWidget {
  const ScheduleSummaryCard({
    super.key,
    required this.drug,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.timing,
    this.stock,
    this.maxDoses,
    this.onEdit,
  });

  final DrugCatalogItem drug;
  final double dose;
  final DoseFrequency frequency;
  final List<DoseTime> times;
  final IntakeTiming timing;
  final int? stock;
  final int? maxDoses;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final doseStr =
        '${formatQuantity(dose)} ${drug.unit.isEmpty ? "viên" : drug.unit}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DosageFormTile(dosageForm: drug.dosageForm, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drug.name, style: AppTextStyles.bodyStrong),
                    if (drug.strength.isNotEmpty)
                      Text(drug.strength, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa'),
                ),
            ],
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Mỗi lần uống',
            value: doseStr,
            icon: Icons.medication_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Tần suất',
            value: frequency.label,
            icon: Icons.repeat_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (frequency.isAsNeeded)
            _SummaryRow(
              label: 'Giờ uống',
              value:
                  'Khi cần (tối đa ${maxDoses ?? defaultMaxDosesPerDay} lần/ngày)',
              icon: Icons.access_time_rounded,
            )
          else
            _SummaryRow(
              label: 'Giờ uống',
              value: times.map((t) => t.format()).join(', '),
              icon: Icons.access_time_rounded,
            ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Thời điểm',
            value: timing.label,
            icon: Icons.restaurant_outlined,
          ),
          if (stock != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(
              label: 'Số lượng hiện có',
              value: '$stock ${drug.unit.isEmpty ? "viên" : drug.unit}',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brand),
        const SizedBox(width: AppSpacing.sm),
        Text('$label: ',
            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyStrong,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// Bottom Sheet hiển thị chi tiết thông tin thuốc theo Figma S07-M2i (Node 492:9562).
class DrugInfoSheet extends StatelessWidget {
  const DrugInfoSheet({super.key, required this.drug});

  final DrugCatalogItem drug;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber handle
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(drug.name, style: AppTextStyles.heading),
                      const SizedBox(height: 2),
                      Text(
                        drugSubtitle(drug.activeIngredient, drug.dosageForm),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Đóng',
                ),
              ],
            ),
            const Divider(height: 24),
            // Facts
            _InfoFactRow(
                label: 'Hoạt chất',
                value: drug.activeIngredient.isNotEmpty
                    ? drug.activeIngredient
                    : 'Chưa có thông tin'),
            const SizedBox(height: 8),
            _InfoFactRow(
                label: 'Hàm lượng',
                value:
                    drug.strength.isNotEmpty ? drug.strength : 'Theo chỉ định'),
            const SizedBox(height: 8),
            _InfoFactRow(
                label: 'Dạng bào chế',
                value: drug.dosageForm.isNotEmpty ? drug.dosageForm : 'Viên'),
            const SizedBox(height: 8),
            const _InfoFactRow(
                label: 'Liều tối đa', value: '4 g/ngày (người lớn)'),
            const Divider(height: 24),
            // Cong dung
            const Text('Công dụng', style: AppTextStyles.bodyStrong),
            const SizedBox(height: 4),
            const Text(
              'Giảm đau nhẹ đến vừa, hạ sốt.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            // Caution box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cautionBg,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: AppColors.cautionText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không uống rượu bia. Thận trọng nếu đang dùng thuốc chống đông như Warfarin.',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.cautionText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nguồn: Dược thư Quốc gia Việt Nam',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.inkDisabled),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoFactRow extends StatelessWidget {
  const _InfoFactRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
        Text(value, style: AppTextStyles.bodyStrong),
      ],
    );
  }
}

Future<void> showDrugInfoSheet(BuildContext context, DrugCatalogItem drug) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => DrugInfoSheet(drug: drug),
  );
}

/// Màn hình hoàn tất thêm thuốc theo chuẩn Figma S07-M4 (Node 452:1888).
class MedicationSuccessView extends StatelessWidget {
  const MedicationSuccessView({
    super.key,
    required this.medication,
    required this.onHome,
    required this.onAddAnother,
    this.noInteractionsFound = false,
  });

  final Medication medication;
  final VoidCallback onHome;
  final VoidCallback onAddAnother;
  final bool noInteractionsFound;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Celebration badge
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Đã thêm thuốc!',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 8),
              Text(
                '${medication.name} · ${medication.frequency.label}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              if (noInteractionsFound)
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.safeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check,
                            size: 16, color: AppColors.safe),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Không có tương tác nguy hiểm',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.safe,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              // Buttons
              FilledButton(
                onPressed: onHome,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                ),
                child: const Text('Về trang chủ'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAddAnother,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Thêm thuốc khác'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ kết quả tìm kiếm thuốc theo Figma S07-M1 (Node 492:7535).
class FigmaSearchResultCard extends StatelessWidget {
  const FigmaSearchResultCard({
    super.key,
    required this.drug,
    required this.onTap,
    this.inUse = false,
  });

  final DrugCatalogItem drug;
  final VoidCallback onTap;
  final bool inUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                DosageFormIcon(
                  dosageForm: drug.dosageForm,
                  size: 48,
                  backgroundColor: AppColors.brandTint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        drug.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF211D1D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [drug.activeIngredient, drug.dosageForm]
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5B6169),
                        ),
                      ),
                      if (drug.strength.isNotEmpty)
                        Text(drug.strength, style: AppTextStyles.caption),
                      if (inUse)
                        const Text('Đang dùng', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF5B6169),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Giao diện tìm kiếm không thấy theo Figma S07-M1e (Node 452:1743).
class FigmaSearchEmptyView extends StatelessWidget {
  const FigmaSearchEmptyView({
    super.key,
    required this.query,
    required this.onScan,
  });

  final String query;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: Color(0xFF5B6169),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa tìm thấy "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF211D1D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thử gõ tên hoạt chất, hoặc quét vỏ hộp để DrugTime tự điền.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF5B6169),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.document_scanner_outlined, size: 20),
            label: const Text(
              'Quét vỏ hộp',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút "Quét vỏ hộp để tự điền" dưới cùng danh sách theo Figma S07-M1 (Node 492:7599).
class FigmaScanTriggerFooter extends StatelessWidget {
  const FigmaScanTriggerFooter({super.key, required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Không thấy thuốc của bạn?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF5B6169),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(
              Icons.document_scanner_outlined,
              size: 20,
              color: AppColors.brand,
            ),
            label: Stack(
              alignment: Alignment.centerLeft,
              children: const [
                Text(
                  'Quét vỏ hộp để tự điền',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
                Opacity(
                  opacity: 0,
                  child: Text('Quét vỏ thuốc', style: TextStyle(fontSize: 1)),
                ),
              ],
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE7F3F1),
              foregroundColor: AppColors.brand,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header thẻ thuốc đã chọn theo Figma S07-M2 (Node 492:7816) và S07-M3 (Node 492:8273).
class FigmaPickedDrugHeaderCard extends StatelessWidget {
  const FigmaPickedDrugHeaderCard({
    super.key,
    required this.drug,
    this.onInfo,
    this.onChange,
    this.tags,
  });

  final DrugCatalogItem drug;
  final VoidCallback? onInfo;
  final VoidCallback? onChange;
  final List<String>? tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DosageFormIcon(
                dosageForm: drug.dosageForm,
                size: 48,
                backgroundColor: AppColors.brandTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF211D1D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${drug.activeIngredient.isNotEmpty ? drug.activeIngredient : 'Hoạt chất'} · ${drug.dosageForm.isNotEmpty ? drug.dosageForm : 'Viên nén'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B6169),
                      ),
                    ),
                  ],
                ),
              ),
              if (onInfo != null)
                IconButton(
                  tooltip: 'Xem chi tiết thuốc',
                  onPressed: onInfo,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE7F3F1),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(
                    Icons.info_outline,
                    color: AppColors.brand,
                    size: 20,
                  ),
                )
              else if (onChange != null)
                TextButton(
                  onPressed: onChange,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE7F3F1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đổi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                ),
            ],
          ),
          if (tags != null && tags!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags!
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5B6169),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ Lịch uống theo Figma S07-M2 (Node 492:7836).
class FigmaScheduleInputCard extends StatelessWidget {
  const FigmaScheduleInputCard({
    super.key,
    required this.dose,
    required this.unit,
    required this.onDoseChanged,
    required this.frequency,
    required this.onFrequencyChanged,
    required this.times,
    required this.onAddTime,
    required this.onEditTime,
    required this.onRemoveTime,
    required this.timing,
    required this.onTimingChanged,
    this.maxDoses = 3,
    this.onMaxDosesChanged,
  });

  final double dose;
  final String unit;
  final ValueChanged<double> onDoseChanged;
  final DoseFrequency frequency;
  final ValueChanged<DoseFrequency> onFrequencyChanged;
  final List<DoseTime> times;
  final VoidCallback onAddTime;
  final void Function(int index) onEditTime;
  final void Function(int index) onRemoveTime;
  final IntakeTiming timing;
  final ValueChanged<IntakeTiming> onTimingChanged;
  final int maxDoses;
  final ValueChanged<int>? onMaxDosesChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: Mỗi lần uống
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Mỗi lần uống',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF211D1D),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F1ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Giảm liều',
                      onPressed: dose > 0.5
                          ? () => onDoseChanged(dose <= 1 ? 0.5 : dose - 1)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.remove,
                          size: 18, color: Color(0xFF211D1D)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${dose % 1 == 0 ? dose.toInt() : dose} $unit',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF211D1D),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tăng liều',
                      onPressed: () =>
                          onDoseChanged(dose == 0.5 ? 1 : dose + 1),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.add,
                          size: 18, color: Color(0xFF211D1D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFEEF0EF), height: 1),
          ),

          // Tần suất uống (Các mốc chuẩn Figma)
          const Text(
            'Tần suất',
            style: TextStyle(fontSize: 14, color: Color(0xFF5B6169)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in DoseFrequency.selectable)
                ChoiceChip(
                  label: Text(f.label),
                  showCheckmark: false,
                  selected: f == frequency,
                  onSelected: (selected) {
                    if (selected) onFrequencyChanged(f);
                  },
                  selectedColor: AppColors.brand,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        f == frequency ? Colors.white : const Color(0xFF211D1D),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: f == frequency
                          ? AppColors.brand
                          : const Color(0xFFE4E4E1),
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFEEF0EF), height: 1),
          ),

          // Dòng 2: Giờ uống hoặc Khi cần
          if (frequency.isAsNeeded) ...[
            const Row(
              children: [
                Icon(Icons.notifications_off_outlined,
                    size: 20, color: Color(0xFF5B6169)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thuốc dùng khi cần sẽ không có lịch nhắc. Bạn tự ghi lại mỗi lần uống.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5B6169)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Tối đa mỗi ngày',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF211D1D)),
                ),
                DoseStepper(
                  key: const ValueKey('max-doses-stepper'),
                  value: maxDoses.toDouble(),
                  unit: 'lần/ngày',
                  min: minMaxDosesPerDay.toDouble(),
                  max: maxMaxDosesPerDay.toDouble(),
                  decreaseTooltip: 'Giảm số lần tối đa',
                  increaseTooltip: 'Tăng số lần tối đa',
                  onChanged: (v) => onMaxDosesChanged?.call(v.round()),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Giờ uống',
              style: TextStyle(fontSize: 14, color: Color(0xFF5B6169)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < times.length; i++)
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => onEditTime(i),
                          child: Text(
                            times[i].format(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (times.length > 1)
                          InkWell(
                            onTap: () => onRemoveTime(i),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.brand,
                            ),
                          ),
                      ],
                    ),
                  ),
                Tooltip(
                  message: 'Thêm giờ',
                  child: OutlinedButton(
                    onPressed: onAddTime,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.square(48),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      side: const BorderSide(color: Color(0xFFE4E4E1)),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Color(0xFFEEF0EF), height: 1),
          ),

          // Dòng 3: Uống khi nào
          const Text(
            'Uống khi nào',
            style: TextStyle(fontSize: 14, color: Color(0xFF5B6169)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MealTimingOption(
                  label: 'Trước ăn',
                  selected: timing == IntakeTiming.beforeMeal,
                  onTap: () => onTimingChanged(IntakeTiming.beforeMeal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MealTimingOption(
                  label: 'Sau ăn',
                  selected: timing == IntakeTiming.afterMeal,
                  onTap: () => onTimingChanged(IntakeTiming.afterMeal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MealTimingOption(
                  label: 'Bất kỳ',
                  selected: timing == IntakeTiming.anytime,
                  onTap: () => onTimingChanged(IntakeTiming.anytime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealTimingOption extends StatelessWidget {
  const _MealTimingOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.brand : const Color(0xFFE4E4E1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF211D1D),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ Tóm tắt xác nhận theo Figma S07-M3 (Node 492:8294).
class FigmaConfirmSummaryCard extends StatelessWidget {
  const FigmaConfirmSummaryCard({
    super.key,
    required this.doseText,
    required this.timesText,
    required this.timingText,
    required this.totalPerDayText,
  });

  final String doseText;
  final String timesText;
  final String timingText;
  final String totalPerDayText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SummaryLine(label: 'Mỗi lần', value: doseText),
          const Divider(color: Color(0xFFEEF0EF), height: 16),
          _SummaryLine(label: 'Giờ uống', value: timesText),
          const Divider(color: Color(0xFFEEF0EF), height: 16),
          _SummaryLine(label: 'Uống khi nào', value: timingText),
          const Divider(color: Color(0xFFEEF0EF), height: 16),
          _SummaryLine(label: 'Tổng mỗi ngày', value: totalPerDayText),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 15, color: Color(0xFF5B6169))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF211D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ Lưu ý an toàn theo Figma S07-M3 (Node 492:8310).
class FigmaSafetyNoteCard extends StatelessWidget {
  const FigmaSafetyNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.brand, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'DrugTime kiểm tra tương tác với các thuốc bạn đang dùng trước khi lưu.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5B6169),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
