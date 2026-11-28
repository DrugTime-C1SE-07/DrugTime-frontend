import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/notification/notification_preferences.dart';
import '../../../../core/notification/reminder_scheduler.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import '../widgets/drug_info_sheet.dart';
import '../widgets/medication_error_messages.dart';
import '../widgets/medication_form_fields.dart';
import '../widgets/medication_labels.dart';
import '../widgets/pill_appearance_icon.dart';
import 'edit_medication_screen.dart';

/// S06a · Xem chi tiết thuốc.
///
/// Hiển thị toàn bộ thông tin về thuốc, liều dùng, lịch uống trong ngày,
/// ngày uống, trạng thái nhắc nhở, dạng & màu viên, tồn kho và lưu ý an toàn.
class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({
    super.key,
    required this.medication,
    this.dosageForm,
  });

  final Medication medication;

  /// Dạng bào chế hiển thị; mặc định lấy từ [medication].
  final String? dosageForm;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  late Medication _medication;
  bool _busy = false;

  String? get _dosageForm => widget.dosageForm ?? _medication.dosageForm;

  @override
  void initState() {
    super.initState();
    _medication = widget.medication;
  }

  Future<void> _openEditScreen() async {
    final scheduler = ReminderSchedulerScope.maybeOf(context);
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => EditMedicationScreen(
          medication: _medication,
          dosageForm: _dosageForm,
          reminderScheduler: scheduler,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result is Map && result['deleted'] == true) {
      // Đã xoá thuốc, thoát khỏi màn hình chi tiết
      Navigator.of(context).pop();
      return;
    }

    if (result is Medication) {
      setState(() {
        _medication = result;
      });
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = _medication.isActive
        ? MedicationStatus.stopped
        : MedicationStatus.active;
    final isStopping = newStatus == MedicationStatus.stopped;

    if (isStopping) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ngừng dùng thuốc?'),
          content: Text(
            'Thuốc "${_medication.name}" sẽ chuyển vào danh sách Đã ngừng và tắt nhắc giờ uống.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.cautionText),
              child: const Text('Xác nhận ngừng'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final controller = MedicationScope.read(context);
    setState(() => _busy = true);
    final Medication updated;
    try {
      // Ngừng: đóng lịch nhắc. Dùng lại: server mở lại đúng giờ uống trước khi ngừng.
      updated = await controller.setStopped(_medication.id, isStopping);
    } on MedicationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMedicationFailure(context, failure);
      return;
    }
    if (!mounted) return;

    setState(() {
      _medication = updated;
      _busy = false;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isStopping
                ? 'Đã chuyển ${_medication.name} sang Đã ngừng'
                : 'Đã kích hoạt lại ${_medication.name}',
          ),
        ),
      );
  }

  Future<void> _confirmDeleteMedication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá thuốc?'),
        content: Text(
          'Bạn có chắc chắn muốn xoá "${_medication.name}" khỏi danh sách thuốc không? '
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xoá thuốc'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final controller = MedicationScope.read(context);
    setState(() => _busy = true);
    try {
      await controller.delete(_medication.id);
    } on MedicationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMedicationFailure(context, failure);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xoá ${_medication.name} khỏi danh sách thuốc'),
        ),
      );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final med = _medication;
    final active = med.isActive;
    final dosageFormText = _dosageForm ?? 'Chưa có thông tin';
    final showLowStockPrefs =
        NotificationPreferencesScope.maybeOf(context)?.reminders.lowStockAlerts ??
            true;
    final showLowStockWarning = showLowStockPrefs && med.isLowStock;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Center(
            child: IconButton(
              tooltip: 'Quay lại',
              icon: const Icon(Icons.chevron_left, color: AppColors.brand),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brandTint,
                minimumSize: const Size.square(AppSizes.tapTarget),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: const Text(
          'Chi tiết thuốc',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('detail-drug-info'),
            tooltip: 'Xem thông tin thuốc',
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.tapTarget),
            ),
            icon: const Icon(Icons.info_outline, color: AppColors.brand),
            onPressed: () => showMedicationInfoSheet(context, med),
          ),
          if (active)
            IconButton(
              tooltip: 'Sửa thông tin thuốc',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSizes.tapTarget),
              ),
              icon: const Icon(Icons.edit_outlined, color: AppColors.brand),
              onPressed: _openEditScreen,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          // 1. Header Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillAppearanceTile(
                  key: const Key('detail-appearance'),
                  shape: med.pillShape,
                  color: med.pillColor,
                  dosageForm: _dosageForm,
                  size: 52,
                  muted: !active,
                  background: AppColors.surface,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        drugSubtitle(med.activeIngredient, _dosageForm),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.safeBg
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              active
                                  ? Icons.check_circle
                                  : Icons.pause_circle_outline,
                              size: 16,
                              color:
                                  active ? AppColors.safe : AppColors.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                active ? 'Đang dùng' : 'Đã ngừng',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? AppColors.safe
                                      : AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Tóm tắt chỉ định liều lượng
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final stackCards = constraints.maxWidth / textScale < 240;
              final cards = [
                _MetricCard(
                  title: 'Số lượng/lần',
                  value: med.doseLabel,
                  icon: Icons.medication,
                ),
                _MetricCard(
                  title: 'Tần suất',
                  value: med.maxDosesLabel ?? med.frequencyLabel,
                  icon: Icons.repeat,
                ),
                _MetricCard(
                  title: 'Cách uống',
                  value: med.timing.label,
                  icon: Icons.restaurant,
                ),
              ];
              if (stackCards) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      cards[i],
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // 3. Lịch uống trong ngày
          const Text('Giờ uống trong ngày', style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          if (med.frequency.isAsNeeded)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.inkMuted, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Uống khi cần thiết theo chỉ định. Không có giờ nhắc cố định.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.field),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (final (i, t) in med.times.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brandTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.schedule,
                              size: 20,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lần ${i + 1}',
                                    style: AppTextStyles.caption),
                                Text(
                                  'Nhắc uống lúc ${t.format()}',
                                  style: AppTextStyles.bodyStrong,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.format(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // 4. Thông tin chi tiết dược lý & tồn kho
          const Text('Thông tin chi tiết', style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Tên biệt dược', value: med.name),
                const Divider(height: 1),
                _DetailRow(
                  label: 'Hoạt chất chính',
                  value: med.activeIngredient.isEmpty
                      ? 'Chưa có thông tin'
                      : med.activeIngredient,
                ),
                const Divider(height: 1),
                _DetailRow(label: 'Hàm lượng', value: med.strength),
                const Divider(height: 1),
                _DetailRow(label: 'Dạng bào chế', value: dosageFormText),
                const Divider(height: 1),
                _DetailRow(label: 'Đơn vị tính', value: med.unit),
                if (!med.frequency.isAsNeeded) ...[
                  const Divider(height: 1),
                  _DetailRow(label: 'Ngày uống', value: med.daysLabel),
                  const Divider(height: 1),
                  _DetailRow(label: 'Nhắc nhở', value: med.reminderLabel),
                ],
                const Divider(height: 1),
                _DetailRow(
                  label: 'Dạng & màu hiển thị',
                  value: med.appearanceDisplayLabel,
                ),
                const Divider(height: 1),
                _DetailRow(
                  label: 'Số lượng tồn kho',
                  value: med.stockRemaining != null
                      ? 'Còn ${med.stockRemaining} ${med.unit}'
                      : 'Chưa theo dõi',
                  isWarning: showLowStockWarning,
                  warningText: showLowStockWarning ? 'Sắp hết thuốc' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 5. Lưu ý an toàn
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 20, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Luôn uống thuốc đúng giờ và theo đúng liều lượng chỉ định của bác sĩ. Không tự ý ngưng hoặc thay đổi liều.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),

      // Bottom bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: active
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _openEditScreen,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.onBrand,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text(
                        'Sửa thông tin thuốc',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _busy ? null : _toggleStatus,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cautionText,
                        side: const BorderSide(color: AppColors.caution),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                      ),
                      child: const Text(
                        'Tạm ngừng thuốc này',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InfoNote(
                      text:
                          'Thuốc đang tạm ngừng. Hãy tiếp tục dùng thuốc này nếu muốn chỉnh sửa thông tin.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _busy ? null : _toggleStatus,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.onBrand,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                      ),
                      child: const Text(
                        'Tiếp tục dùng thuốc này',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _confirmDeleteMedication,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text(
                        'Xoá thuốc',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isWarning = false,
    this.warningText,
  });

  final String label;
  final String value;
  final bool isWarning;
  final String? warningText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.caption),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isWarning ? AppColors.danger : AppColors.ink,
                  ),
                ),
                if (warningText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    warningText!,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.captionStrong
                        .copyWith(color: AppColors.cautionText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
