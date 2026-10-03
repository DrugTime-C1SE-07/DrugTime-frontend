import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import '../widgets/medication_error_messages.dart';
import '../widgets/medication_form_fields.dart';
import '../widgets/medication_labels.dart';

/// S06b · Sửa thông tin thuốc (Figma prototype).
///
/// Cho phép người dùng chỉnh sửa liều lượng, tần suất, giờ uống,
/// cách uống đối với bữa ăn, hoặc xoá thuốc khỏi danh sách.
class EditMedicationScreen extends StatefulWidget {
  const EditMedicationScreen({
    super.key,
    required this.medication,
    this.dosageForm,
  });

  final Medication medication;

  /// Dạng bào chế hiển thị; mặc định lấy từ [medication].
  final String? dosageForm;

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  late double _dose;
  late int _maxDoses;
  late DoseFrequency _frequency;
  late List<DoseTime> _times;
  late IntakeTiming _timing;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dose = widget.medication.dosePerIntake;
    _maxDoses = widget.medication.maxDosesPerDay ?? defaultMaxDosesPerDay;
    _frequency = widget.medication.frequency;
    _times = List<DoseTime>.from(widget.medication.times);
    _timing = widget.medication.timing;
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDose() async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn số lượng mỗi lần uống', style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: List.generate(8, (i) {
                    final value = (i + 1).toDouble();
                    final isCurrent = value == _dose;
                    return ChoiceChip(
                      label: Text('${formatQuantity(value)} ${widget.medication.unit}'),
                      selected: isCurrent,
                      selectedColor: AppColors.brandTint,
                      labelStyle: TextStyle(
                        color: isCurrent ? AppColors.brand : AppColors.ink,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) => Navigator.of(context).pop(value),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != _dose) {
      setState(() {
        _dose = selected;
        _markDirty();
      });
    }
  }

  Future<void> _pickFrequency() async {
    final selected = await showModalBottomSheet<DoseFrequency>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn tần suất uống thuốc', style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.md),
                for (final freq in DoseFrequency.selectable)
                  ListTile(
                    title: Text(freq.label, style: AppTextStyles.bodyStrong),
                    trailing: freq == _frequency
                        ? const Icon(Icons.check, color: AppColors.brand)
                        : null,
                    onTap: () => Navigator.of(context).pop(freq),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != _frequency) {
      setState(() {
        _frequency = selected;
        if (selected == DoseFrequency.asNeeded) {
          _times = const [];
        } else if (_times.isEmpty) {
          _times = List<DoseTime>.from(selected.defaultTimes);
        }
        _markDirty();
      });
    }
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Thêm giờ uống',
      cancelText: 'Huỷ',
      confirmText: 'Thêm',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final next = DoseTime(picked.hour, picked.minute);
    if (_times.contains(next)) {
      _toast('Đã có lần uống lúc ${next.format()}. Vui lòng chọn giờ khác.');
      return;
    }

    setState(() {
      _times = [..._times, next]..sort();
      _markDirty();
    });
  }

  Future<void> _editTime(DoseTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Đổi giờ uống',
      cancelText: 'Huỷ',
      confirmText: 'Lưu',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final next = DoseTime(picked.hour, picked.minute);
    if (next != current && _times.contains(next)) {
      _toast('Đã có lần uống lúc ${next.format()}.');
      return;
    }

    setState(() {
      _times.remove(current);
      _times = [..._times, next]..sort();
      _markDirty();
    });
  }

  void _removeTime(DoseTime time) {
    if (_times.length <= 1 && !_frequency.isAsNeeded) {
      _toast('Cần ít nhất một giờ nhắc thuốc.');
      return;
    }
    setState(() {
      _times.remove(time);
      _markDirty();
    });
  }

  Future<void> _saveMedication() async {
    if (_saving) return;
    setState(() => _saving = true);
    final controller = MedicationScope.read(context);

    final edited = widget.medication.copyWith(
      dosePerIntake: _dose,
      frequency: _frequency,
      timing: _timing,
      times: _frequency.isAsNeeded ? const [] : _times,
      maxDosesPerDay: _frequency.isAsNeeded ? _maxDoses : null,
    );

    final Medication updated;
    try {
      // Chỉ phần khác bản gốc được gửi lên (PATCH).
      updated = await controller.update(widget.medication, edited);
    } on MedicationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(medicationErrorMessage(failure));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.safeBg),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Đã cập nhật ${updated.name}')),
            ],
          ),
        ),
      );

    Navigator.of(context).pop(updated);
  }

  Future<void> _confirmDeleteMedication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá thuốc?'),
        content: Text(
          'Bạn có chắc chắn muốn xoá "${widget.medication.name}" khỏi danh sách thuốc không? '
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
    setState(() => _saving = true);
    try {
      await controller.delete(widget.medication.id);
    } on MedicationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(medicationErrorMessage(failure));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xoá ${widget.medication.name} khỏi danh sách thuốc'),
        ),
      );

    // Pop về danh sách thuốc (nếu màn trước là Detail, pop cả 2 màn hoặc pop kèm tín hiệu deleted)
    Navigator.of(context).pop({'deleted': true, 'id': widget.medication.id});
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ các thay đổi?'),
        content: const Text(
          'Các thông tin vừa sửa chưa được lưu. Bạn có chắc muốn thoát mà không lưu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tiếp tục sửa'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _leaveIfConfirmed() async {
    final leave = await _confirmDiscard();
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = drugSubtitle(
      widget.medication.activeIngredient,
      widget.dosageForm ?? widget.medication.dosageForm,
    );

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveIfConfirmed();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () {
              if (_dirty) {
                _leaveIfConfirmed();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: const Text(
            'Sửa thông tin thuốc',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          centerTitle: false,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          children: [
            const SizedBox(height: AppSpacing.md),

            // 1. Thẻ thông tin thuốc ở trên cùng
            _DrugInfoCard(
              name: widget.medication.name,
              subtitle: subtitle,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 2. Hai cột: Số lượng/lần & Tần suất
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Số lượng/lần', style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectBox(
                        label: '${formatQuantity(_dose)} ${widget.medication.unit}',
                        onTap: _pickDose,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tần suất', style: AppTextStyles.bodyStrong),
                      const SizedBox(height: AppSpacing.sm),
                      _SelectBox(
                        label: _frequency == DoseFrequency.custom
                            ? '${_times.length} lần/ngày'
                            : _frequency.label,
                        hasDropdownIcon: true,
                        onTap: _pickFrequency,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Giờ uống
            const Text('Giờ uống', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            if (_frequency.isAsNeeded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Thuốc dùng khi cần, không có lịch nhắc cố định.',
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Tối đa mỗi ngày', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              DoseStepper(
                key: const ValueKey('max-doses-stepper'),
                value: _maxDoses.toDouble(),
                unit: 'lần/ngày',
                min: minMaxDosesPerDay.toDouble(),
                max: maxMaxDosesPerDay.toDouble(),
                decreaseTooltip: 'Giảm số lần tối đa',
                increaseTooltip: 'Tăng số lần tối đa',
                onChanged: (v) => setState(() {
                  _maxDoses = v.round();
                  _markDirty();
                }),
              ),
            ] else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final t in _times)
                    _DoseTimeChip(
                      time: t,
                      onTap: () => _editTime(t),
                      onDelete: () => _removeTime(t),
                    ),
                  _AddTimeChip(onTap: _addTime),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Uống thế nào
            const Text('Uống thế nào', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            _TimingSegmentRow(
              currentTiming: _timing,
              onSelect: (timing) {
                if (timing != _timing) {
                  setState(() {
                    _timing = timing;
                    _markDirty();
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),

        // Nút Lưu và Xoá thuốc cố định ở đáy
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nút Lưu
                FilledButton(
                  onPressed: _saving ? null : _saveMedication,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF01554F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20, color: Colors.white),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Lưu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Nút Xoá thuốc
                OutlinedButton(
                  onPressed: _saving ? null : _confirmDeleteMedication,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE53935)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Color(0xFFE53935)),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Xoá thuốc',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ thuốc xanh nhạt trên cùng
class _DrugInfoCard extends StatelessWidget {
  const _DrugInfoCard({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const PillIcon(size: 24, color: Color(0xFF01554F)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung chọn dạng ô input trắng có viền bo góc
class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.label,
    this.hasDropdownIcon = false,
    required this.onTap,
  });

  final String label;
  final bool hasDropdownIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.ink,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              if (hasDropdownIcon)
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.inkMuted,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip giờ uống xanh nhạt có nút xoá '✕'
class _DoseTimeChip extends StatelessWidget {
  const _DoseTimeChip({
    required this.time,
    required this.onTap,
    required this.onDelete,
  });

  final DoseTime time;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3F1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 14,
                top: 8,
                bottom: 8,
                right: 4,
              ),
              child: Text(
                time.format(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF01554F),
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.only(
                left: 2,
                top: 8,
                bottom: 8,
                right: 12,
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF01554F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút "+ Thêm giờ"
class _AddTimeChip extends StatelessWidget {
  const _AddTimeChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: AppColors.ink),
              SizedBox(width: 4),
              Text(
                'Thêm giờ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dãy 3 nút "Trước ăn", "Sau ăn", "Không liên quan"
class _TimingSegmentRow extends StatelessWidget {
  const _TimingSegmentRow({
    required this.currentTiming,
    required this.onSelect,
  });

  final IntakeTiming currentTiming;
  final ValueChanged<IntakeTiming> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (IntakeTiming.beforeMeal, 'Trước ăn'),
      (IntakeTiming.afterMeal, 'Sau ăn'),
      (IntakeTiming.anytime, 'Không liên quan'),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TimingButton(
              label: items[i].$2,
              selected: currentTiming == items[i].$1,
              onTap: () => onSelect(items[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimingButton extends StatelessWidget {
  const _TimingButton({
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
      color: selected ? const Color(0xFF01554F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFF01554F) : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
