import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/notification/reminder_scheduler.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import '../../../drug_food_warning/domain/repositories/food_interaction_repository.dart';
import '../../../drug_food_warning/presentation/widgets/food_warning_dialog.dart';
import '../../../interaction_check/presentation/widgets/interaction_warning_dialog.dart';
import '../../data/models/medication_api_mapper.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import '../widgets/drug_info_sheet.dart';
import '../widgets/medication_error_messages.dart';
import '../widgets/medication_form_fields.dart';
import '../widgets/medication_labels.dart';
import '../widgets/pill_appearance_icon.dart';
import 'pill_appearance_screen.dart';

/// S06b · Sửa thông tin thuốc (Figma `144:296`).
class EditMedicationScreen extends StatefulWidget {
  const EditMedicationScreen({
    super.key,
    required this.medication,
    this.dosageForm,
    this.reminderScheduler,
    this.foodInteractionRepository,
  });

  final Medication medication;

  /// Dạng bào chế hiển thị; mặc định lấy từ [medication].
  final String? dosageForm;

  final ReminderScheduler? reminderScheduler;

  final FoodInteractionRepository? foodInteractionRepository;

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  static const int _maxIntakeTimes = 6;
  static const int _maxStock = 9999;
  static const List<double> _dosePresets = [
    0.5,
    1.0,
    1.5,
    2.0,
    2.5,
    3.0,
    4.0,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0,
    10.0,
  ];

  late double _dose;
  late int _maxDoses;
  late DoseFrequency _frequency;
  late List<DoseTime> _times;
  late List<int> _daysOfWeek;
  late IntakeTiming _timing;
  late bool _reminderEnabled;
  late PillShape? _pillShape;
  late PillColor? _pillColor;
  late final TextEditingController _stockController;

  bool _reminderTouched = false;
  bool _dirty = false;
  bool _saving = false;
  String? _stockError;
  String? _daysError;

  bool get _isPartialReminder =>
      widget.medication.reminderState == MedicationReminderState.partial;

  String? get _effectiveDosageForm =>
      widget.dosageForm ?? widget.medication.dosageForm;

  @override
  void initState() {
    super.initState();
    _dose = widget.medication.dosePerIntake;
    _maxDoses = widget.medication.maxDosesPerDay ?? defaultMaxDosesPerDay;
    _frequency = widget.medication.frequency;
    _times = List<DoseTime>.from(widget.medication.times);
    _daysOfWeek = List<int>.from(widget.medication.daysOfWeek);
    _timing = widget.medication.timing;
    _reminderEnabled =
        _isPartialReminder ? true : widget.medication.reminderEnabled;
    _pillShape = widget.medication.pillShape;
    _pillColor = widget.medication.pillColor;
    _stockController = TextEditingController(
      text: widget.medication.stockRemaining?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
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
    final customController = TextEditingController();
    String? customError;
    final selected = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chọn số lượng mỗi lần uống',
                        style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final value in _dosePresets)
                          ChoiceChip(
                            label: Text(
                              '${formatQuantity(value)} ${widget.medication.unit}',
                              style: TextStyle(
                                fontSize: 14,
                                color: value == _dose
                                    ? AppColors.brand
                                    : AppColors.ink,
                                fontWeight: value == _dose
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: value == _dose,
                            selectedColor: AppColors.brandTint,
                            onSelected: (_) =>
                                Navigator.of(sheetContext).pop(value),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('edit_dose_custom_input'),
                            controller: customController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              hintText: 'Hoặc nhập (0 < liều ≤ 10)',
                              errorText: customError,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: () {
                            final raw =
                                customController.text.trim().replaceAll(',', '.');
                            final parsed = double.tryParse(raw);
                            if (parsed == null || parsed <= 0 || parsed > 10) {
                              setSheetState(() {
                                customError = 'Nhập số > 0 và ≤ 10';
                              });
                              return;
                            }
                            Navigator.of(sheetContext).pop(parsed);
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(88, AppSizes.field),
                          ),
                          child: const Text('Áp dụng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    customController.dispose();

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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
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
                const Text('Chọn tần suất uống thuốc',
                    style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.md),
                for (final freq in DoseFrequency.selectable)
                  ListTile(
                    minTileHeight: AppSizes.tapTarget,
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
          _daysError = null;
        } else {
          _times = List<DoseTime>.from(selected.defaultTimes);
        }
        _markDirty();
      });
    }
  }

  Future<void> _addTime() async {
    if (_times.length >= _maxIntakeTimes) {
      _toast('Tối đa $_maxIntakeTimes lần uống mỗi ngày.');
      return;
    }

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
      _frequency = DoseFrequency.forTimeCount(_times.length);
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
      _frequency = DoseFrequency.forTimeCount(_times.length);
      _markDirty();
    });
  }

  Future<void> _pickAppearance() async {
    final chosen = await showPillAppearanceScreen(
      context,
      drugName: widget.medication.name,
      dosageForm: _effectiveDosageForm,
      shape: _pillShape,
      color: _pillColor,
      showStepProgress: false,
    );
    if (chosen == null || !mounted) return;
    final (shape, color) = chosen;
    if (shape != _pillShape || color != _pillColor) {
      setState(() {
        _pillShape = shape;
        _pillColor = color;
        _markDirty();
      });
    }
  }

  void _toggleDay(int isoDay) {
    setState(() {
      if (_daysOfWeek.contains(isoDay)) {
        _daysOfWeek.remove(isoDay);
      } else {
        _daysOfWeek = [..._daysOfWeek, isoDay]..sort();
      }
      if (_daysOfWeek.isNotEmpty) _daysError = null;
      _markDirty();
    });
  }

  void _selectEveryDay() {
    setState(() {
      _daysOfWeek = List<int>.from(allDaysOfWeek);
      _daysError = null;
      _markDirty();
    });
  }

  (bool valid, int? stock) _validateStock() {
    final raw = _stockController.text.trim();
    if (raw.isEmpty) {
      return (true, null);
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0 || parsed > _maxStock) {
      return (false, null);
    }
    return (true, parsed);
  }

  Future<void> _saveMedication() async {
    if (_saving) return;

    final (stockValid, parsedStock) = _validateStock();
    final daysValid = _frequency.isAsNeeded || _daysOfWeek.isNotEmpty;
    if (!stockValid || !daysValid) {
      setState(() {
        _stockError =
            stockValid ? null : 'Nhập số nguyên từ 0 đến $_maxStock.';
        _daysError = daysValid ? null : 'Chọn ít nhất một ngày uống.';
      });
      _toast(
        !daysValid
            ? 'Chọn ít nhất một ngày uống.'
            : 'Số lượng tồn kho không hợp lệ (0–$_maxStock).',
      );
      return;
    }

    setState(() {
      _stockError = null;
      _daysError = null;
    });

    final sortedDays = _frequency.isAsNeeded
        ? widget.medication.daysOfWeek
        : (List<int>.from(_daysOfWeek)..sort());
    final effectiveReminder = _frequency.isAsNeeded
        ? widget.medication.reminderEnabled
        : (_isPartialReminder && !_reminderTouched
            ? widget.medication.reminderEnabled
            : _reminderEnabled);

    final edited = widget.medication
        .withAppearance(_pillShape, _pillColor)
        .copyWith(
          dosePerIntake: _dose,
          frequency: _frequency,
          timing: _timing,
          times: _frequency.isAsNeeded ? const [] : _times,
          daysOfWeek: sortedDays,
          maxDosesPerDay: _frequency.isAsNeeded ? _maxDoses : null,
          stockRemaining: parsedStock,
          clearStock: parsedStock == null,
          reminderEnabled: effectiveReminder,
        );

    final patch = MedicationApiMapper.patchBody(widget.medication, edited);
    final reminderChanged = !_frequency.isAsNeeded &&
        _reminderTouched &&
        (_isPartialReminder ||
            _reminderEnabled != widget.medication.reminderEnabled);

    // AC10: Không thay đổi gì thì không gọi interaction check hay PATCH.
    if (patch.isEmpty && !reminderChanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    final controller = MedicationScope.read(context);

    final clinicalChanged =
        edited.dosePerIntake != widget.medication.dosePerIntake ||
            edited.frequency != widget.medication.frequency ||
            edited.timing != widget.medication.timing ||
            edited.maxDosesPerDay != widget.medication.maxDosesPerDay ||
            !_sameTimes(edited.times, widget.medication.times) ||
            (!edited.frequency.isAsNeeded &&
                !_sameInts(edited.daysOfWeek, widget.medication.daysOfWeek));

    final scheduler =
        widget.reminderScheduler ?? ReminderSchedulerScope.maybeOf(context);
    final candidateId = int.tryParse(widget.medication.catalogId);
    if (clinicalChanged && candidateId != null) {
      final patientId =
          AuthScope.maybeOf(context)?.currentSession?.userId ?? '';
      try {
        final otherActiveIds = controller.medications
            .where((m) => m.id != widget.medication.id && m.isActive)
            .map((m) => int.tryParse(m.catalogId))
            .whereType<int>()
            .toList();

        final checkResult = await controller.checkInteractions(
          patientId: patientId,
          candidateMedicationId: candidateId,
          candidateDoseAmount: _dose,
          candidateDoseUnit:
              widget.medication.unit.isEmpty ? null : widget.medication.unit,
          medicationIds: otherActiveIds,
        );

        if (checkResult.hasInteractions) {
          if (!mounted) return;
          setState(() => _saving = false);
          final proceed =
              await showInteractionWarningDialog(context, checkResult);
          if (proceed != true) return;
          if (mounted) setState(() => _saving = true);
        } else if (checkResult.isInsufficientData ||
            checkResult.insufficientDataMedications.isNotEmpty) {
          if (!mounted) return;
          setState(() => _saving = false);
          final proceed =
              await showInsufficientDataDialog(context, checkResult);
          if (proceed != true) return;
          if (mounted) setState(() => _saving = true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        final proceed = await showInteractionNetworkErrorDialog(context);
        if (proceed != true) return;
        if (mounted) setState(() => _saving = true);
      }

      final foodRepo = widget.foodInteractionRepository ??
          InMemoryFoodInteractionRepository();
      try {
        final foodResult = await foodRepo.checkFoodInteractions(
          patientId: patientId,
          medicationName: widget.medication.name,
          activeIngredient: widget.medication.activeIngredient,
          catalogId: candidateId,
        );

        if (foodResult.hasWarnings) {
          if (!mounted) return;
          setState(() => _saving = false);
          final proceed = await showFoodWarningDialog(context, foodResult);
          if (proceed != true) return;
          if (mounted) setState(() => _saving = true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        final proceed = await showFoodNetworkErrorDialog(context);
        if (proceed != true) return;
        if (mounted) setState(() => _saving = true);
      }
    }

    final Medication updated;
    try {
      updated = await controller.saveEdit(
        before: widget.medication,
        after: edited,
        applyReminderToAllSchedules: reminderChanged,
      );
      if (!_frequency.isAsNeeded && reminderChanged && !_reminderEnabled) {
        if (scheduler != null) {
          final scheduleIds = <int>{
            for (final s in widget.medication.schedules) s.id,
            for (final s in updated.schedules) s.id,
          };
          if (scheduleIds.isEmpty) {
            final fallbackId = int.tryParse(widget.medication.id);
            if (fallbackId != null) scheduleIds.add(fallbackId);
          }
          for (final id in scheduleIds) {
            await scheduler.cancelAllForSchedule(id);
          }
        }
      }
    } on MedicationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMedicationFailure(context, failure);
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
      showMedicationFailure(context, failure);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text('Đã xoá ${widget.medication.name} khỏi danh sách thuốc'),
        ),
      );

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
      _effectiveDosageForm,
    );
    final reminderSubtitle = _isPartialReminder && !_reminderTouched
        ? 'Đang bật một phần (${widget.medication.enabledScheduleCount}/${widget.medication.schedules.length} giờ) — gạt để áp dụng chung cho mọi giờ'
        : 'Nhận thông báo khi đến cữ uống thuốc';

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveIfConfirmed();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
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
                onPressed: () {
                  if (_dirty) {
                    _leaveIfConfirmed();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            ),
          ),
          title: const Text(
            'Sửa thông tin thuốc',
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
              key: const Key('edit-drug-info'),
              tooltip: 'Xem thông tin thuốc',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSizes.tapTarget),
              ),
              icon: const Icon(Icons.info_outline, color: AppColors.brand),
              onPressed: () =>
                  showMedicationInfoSheet(context, widget.medication),
            ),
          ],
          centerTitle: false,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          children: [
            const SizedBox(height: AppSpacing.md),

            // 1. Thẻ thông tin thuốc + đổi dạng & màu
            _DrugInfoCard(
              name: widget.medication.name,
              subtitle: subtitle,
              pillShape: _pillShape,
              pillColor: _pillColor,
              dosageForm: _effectiveDosageForm,
              onChangeAppearance: _pickAppearance,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 2. Hai cột: Số lượng/lần & Tần suất
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final stack = constraints.maxWidth / textScale < 240;
                final doseField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số lượng/lần', style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.sm),
                    _SelectBox(
                      label:
                          '${formatQuantity(_dose)} ${widget.medication.unit}',
                      onTap: _pickDose,
                    ),
                  ],
                );
                final freqField = Column(
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
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      doseField,
                      const SizedBox(height: AppSpacing.md),
                      freqField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: doseField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: freqField),
                  ],
                );
              },
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
            ] else ...[
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
                  if (_times.length < _maxIntakeTimes)
                    _AddTimeChip(onTap: _addTime),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 3b. Ngày uống trong tuần (ISO 1..7)
              Row(
                children: [
                  const Expanded(
                    child: Text('Ngày uống', style: AppTextStyles.bodyStrong),
                  ),
                  TextButton(
                    key: const Key('edit-days-everyday'),
                    onPressed: _selectEveryDay,
                    child: const Text('Hằng ngày'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (day, label) in const [
                    (1, 'T2'),
                    (2, 'T3'),
                    (3, 'T4'),
                    (4, 'T5'),
                    (5, 'T6'),
                    (6, 'T7'),
                    (7, 'CN'),
                  ])
                    FilterChip(
                      key: Key('edit-day-$day'),
                      label: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _daysOfWeek.contains(day)
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _daysOfWeek.contains(day)
                              ? AppColors.brand
                              : AppColors.ink,
                        ),
                      ),
                      selected: _daysOfWeek.contains(day),
                      selectedColor: AppColors.brandTint,
                      checkmarkColor: AppColors.brand,
                      onSelected: (_) => _toggleDay(day),
                    ),
                ],
              ),
              if (_daysError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _daysError!,
                  style: AppTextStyles.captionStrong
                      .copyWith(color: AppColors.danger),
                ),
              ],
            ],
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
            const SizedBox(height: AppSpacing.xl),

            // 5. Số lượng tồn kho
            const Text('Số lượng tồn kho', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('edit-stock-input'),
              controller: _stockController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              onChanged: (_) {
                if (_stockError != null) setState(() => _stockError = null);
                _markDirty();
              },
              decoration: InputDecoration(
                hintText: 'Để trống nếu không theo dõi (0–$_maxStock)',
                suffixText: widget.medication.unit,
                errorText: _stockError,
              ),
            ),

            // 6. Bật / Tắt nhắc nhở (chỉ thuốc theo giờ)
            if (!_frequency.isAsNeeded) ...[
              const SizedBox(height: AppSpacing.xl),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: SwitchListTile(
                  key: const Key('edit_medication_reminder_switch'),
                  title: const Text('Bật nhắc nhở',
                      style: AppTextStyles.bodyStrong),
                  subtitle: Text(reminderSubtitle, style: AppTextStyles.caption),
                  value: _reminderEnabled,
                  activeThumbColor: AppColors.brand,
                  onChanged: (val) {
                    setState(() {
                      _reminderEnabled = val;
                      _reminderTouched = true;
                      _markDirty();
                    });
                  },
                ),
              ),
            ],
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
                FilledButton(
                  onPressed: _saving ? null : _saveMedication,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.onBrand,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onBrand,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check,
                                size: 20, color: AppColors.onBrand),
                            SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                'Lưu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onBrand,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _saving ? null : _confirmDeleteMedication,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 20, color: AppColors.danger),
                      SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'Xoá thuốc',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
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

bool _sameTimes(List<DoseTime> a, List<DoseTime> b) {
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  if (sa.length != sb.length) return false;
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] != sb[i]) return false;
  }
  return true;
}

bool _sameInts(List<int> a, List<int> b) {
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  if (sa.length != sb.length) return false;
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] != sb[i]) return false;
  }
  return true;
}

/// Thẻ thuốc xanh nhạt trên cùng kèm nút Đổi dạng & màu.
class _DrugInfoCard extends StatelessWidget {
  const _DrugInfoCard({
    required this.name,
    required this.subtitle,
    required this.pillShape,
    required this.pillColor,
    required this.dosageForm,
    required this.onChangeAppearance,
  });

  final String name;
  final String subtitle;
  final PillShape? pillShape;
  final PillColor? pillColor;
  final String? dosageForm;
  final VoidCallback onChangeAppearance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          PillAppearanceTile(
            key: const Key('edit-appearance-preview'),
            shape: pillShape,
            color: pillColor,
            dosageForm: dosageForm,
            size: 48,
            background: AppColors.surface,
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
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            key: const Key('edit-change-appearance'),
            onPressed: onChangeAppearance,
            child: const Text('Đổi'),
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
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(24)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 14,
                top: 12,
                bottom: 12,
                right: 4,
              ),
              child: Text(
                time.format(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(24)),
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.only(
                left: 4,
                top: 12,
                bottom: 12,
                right: 12,
              ),
              child: Icon(
                Icons.close,
                size: 18,
                color: AppColors.brand,
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
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: const Row(
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stack = constraints.maxWidth / textScale < 240;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _TimingButton(
                  label: items[i].$2,
                  selected: currentTiming == items[i].$1,
                  onTap: () => onSelect(items[i].$1),
                ),
              ],
            ],
          );
        }
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
      },
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
      color: selected ? AppColors.brand : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.onBrand : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
