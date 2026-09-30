import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/medication.dart';

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
              const TextSpan(text: '  (không bắt buộc)', style: AppTextStyles.caption),
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
                child: const Icon(Icons.document_scanner_outlined, color: AppColors.brand),
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
            child: Text(label, textAlign: TextAlign.center, style: AppTextStyles.caption),
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
    this.errorText,
  });

  final DrugCatalogItem? value;
  final VoidCallback onTap;
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
                  child: drug == null ? const _PickerPlaceholder() : _PickedDrug(drug),
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
                const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppTextStyles.captionStrong.copyWith(color: AppColors.danger),
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
  const _PickedDrug(this.drug);

  final DrugCatalogItem drug;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PillTile(size: 40),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(drug.name, style: AppTextStyles.bodyStrong),
              Text(
                '${drug.activeIngredient} · ${drug.dosageForm}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('Đổi', style: AppTextStyles.bodyStrong.copyWith(color: AppColors.brand)),
      ],
    );
  }
}

/// Ô chỉ đọc (giá trị tự điền từ danh mục), nền xám + ổ khoá để phân biệt
/// với ô nhập được.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({super.key, required this.value, required this.placeholder});

  final String? value;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.field),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
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

/// Bộ tăng/giảm liều. Dùng stepper thay cho ô gõ chữ để tránh nhập sai số.
class DoseStepper extends StatelessWidget {
  const DoseStepper({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

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
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: 'Giảm liều',
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                '$value $unit',
                textAlign: TextAlign.center,
                style: AppTextStyles.figure,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'Tăng liều',
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
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
                const Icon(Icons.edit_outlined, size: 20, color: AppColors.inkMuted),
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
  const IntakeTimingSelector({super.key, required this.value, required this.onChanged});

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
  const _RadioRow({required this.label, required this.selected, required this.onTap});

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
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? AppColors.brand : AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: selected ? AppTextStyles.bodyStrong : AppTextStyles.body,
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
  const InfoNote({super.key, required this.text, this.icon = Icons.info_outline});

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
          Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.ink))),
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
          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.cautionText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: AppColors.cautionText),
            ),
          ),
        ],
      ),
    );
  }
}
