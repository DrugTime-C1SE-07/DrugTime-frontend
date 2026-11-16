import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/router.dart';
import '../../../medication_capture/domain/capture_models.dart';
import '../../../medication_capture/data/capture_services.dart';
import '../../../medication_capture/presentation/state/capture_scope.dart';
import '../../../../core/preview/app_preview_scope.dart';
import '../../../../core/storage/local_db/client_uuid.dart';
import '../../../../shared/widgets/selectable_pill.dart';
import '../../../../shared/widgets/two_column_grid.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import '../widgets/drug_catalog_sheet.dart';
import '../widgets/medication_error_messages.dart';
import '../widgets/medication_form_fields.dart';
import '../widgets/medication_labels.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../interaction_check/presentation/widgets/interaction_warning_dialog.dart';

import '../../../drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import '../../../drug_food_warning/domain/repositories/food_interaction_repository.dart';
import '../../../drug_food_warning/presentation/widgets/food_warning_dialog.dart';

/// S07 · Thêm thuốc mới theo luồng 3 bước Figma (Prototype_DrugTime):
/// Bước 1: Thêm thuốc (Tìm kiếm / Quét OCR)
/// Bước 2: Lịch uống (Liều, Tần suất, Giờ uống, Cách uống)
/// Bước 3: Xác nhận (Tóm tắt thông tin, kiểm tra tương tác)
class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.captureLauncher,
    this.foodInteractionRepository,
    this.scannedDrug,
    this.openCaptureOnStart = false,
  });

  final FoodInteractionRepository? foodInteractionRepository;
  final DrugCatalogItem? scannedDrug;
  final Future<CaptureResult?> Function(BuildContext)? captureLauncher;
  final bool openCaptureOnStart;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _drugFieldKey = GlobalKey();
  final _stockController = TextEditingController();

  /// Sinh một lần cho form này: bấm lưu lại sau lỗi mạng gửi cùng giá trị nên server
  /// không tạo thuốc trùng.
  final String _clientUuid = createClientUuid();

  int _currentStep = 0;
  DrugCatalogItem? _drug;
  double _dose = 1;
  int _maxDoses = defaultMaxDosesPerDay;
  DoseFrequency _frequency = DoseFrequency.twice;
  List<DoseTime> _times = DoseFrequency.twice.defaultTimes;
  IntakeTiming _timing = IntakeTiming.afterMeal;

  bool _dirty = false;
  bool _showDrugError = false;
  bool _saving = false;
  bool _openingCapture = false;
  PreparedMedicationImage? _capture;
  Uint8List? _captureBytes;
  Timer? _captureExpiry;
  CaptureServices? _captureServices;

  @override
  void initState() {
    super.initState();
    _drug = widget.scannedDrug;
    if (widget.openCaptureOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openCapture());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _captureServices = CaptureScope.maybeOf(context);
  }

  Future<void> _releaseImage(PreparedMedicationImage lease) async {
    try {
      await lease.release();
    } catch (_) {
      _captureServices?.cleanupError = 'Chưa dọn được ảnh tạm.';
      if (mounted) {
        _toast('Chưa dọn được ảnh tạm. Hãy thử lại.');
      }
    }
  }

  Future<void> _openCapture({bool edit = false}) async {
    if (_openingCapture) return;
    _openingCapture = true;
    PreparedMedicationImage? incoming;
    try {
      final result = widget.captureLauncher != null
          ? await widget.captureLauncher!(context)
          : await Navigator.of(context).pushNamed<CaptureResult>(
              AppRoutes.captureMedication,
              arguments: edit ? _captureBytes : null,
            );

      final selected = result?.drug;
      if (selected != null) {
        if (!mounted) return;
        _update(() {
          _drug = selected;
          _showDrugError = false;
          _currentStep = 1;
        });
      } else if (result?.kind == CaptureResultKind.prepared &&
          result?.image != null) {
        final lease = result!.image!;
        incoming = lease;
        if (!mounted) {
          await lease.release();
          return;
        }
        final bytes = await lease.read();
        if (!mounted) {
          await lease.release();
          return;
        }
        await _discardCapture();
        if (!mounted) {
          await lease.release();
          return;
        }
        setState(() {
          _capture = lease;
          _captureBytes = bytes;
          _dirty = true;
        });
        incoming = null;
        _captureExpiry = Timer(lease.expiresAt.difference(DateTime.now()),
            () => unawaited(_discardCapture()));
      }
    } catch (_) {
      if (incoming != null) {
        await _releaseImage(incoming);
      }
      if (mounted) _toast('Không mở được ảnh. Hãy thử lại.');
    } finally {
      _openingCapture = false;
    }
  }

  Future<void> _discardCapture() async {
    _captureExpiry?.cancel();
    _captureExpiry = null;
    final lease = _capture;
    _capture = null;
    _captureBytes = null;
    if (mounted) setState(() {});
    if (lease != null) {
      await _releaseImage(lease);
    }
  }

  @override
  void dispose() {
    _captureExpiry?.cancel();
    final capture = _capture;
    _capture = null;
    _captureBytes = null;
    if (capture != null) unawaited(_releaseImage(capture));
    _stockController.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDrug() async {
    final picked = await showDrugCatalogSheet(context);
    if (!mounted || picked == null) return;
    _update(() {
      _drug = picked;
      _showDrugError = false;
      _currentStep =
          1; // Tự động sang bước 2 (Lịch uống) theo Figma S07-M1 -> S07-M2
    });
  }

  void _setFrequency(DoseFrequency frequency) {
    if (frequency == _frequency) return;
    _update(() {
      _frequency = frequency;
      _times = frequency.defaultTimes;
    });
  }

  Future<void> _editTime(int index) async {
    final current = _times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Giờ uống lần ${index + 1}',
      cancelText: 'Huỷ',
      confirmText: 'Chọn',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    final next = DoseTime(picked.hour, picked.minute);
    final duplicate = _times.indexed.any((e) => e.$1 != index && e.$2 == next);
    if (duplicate) {
      _toast('Đã có lần uống lúc ${next.format()}. Vui lòng chọn giờ khác.');
      return;
    }
    _update(() => _times = ([..._times]..[index] = next)..sort());
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_drug == null) {
        setState(() => _showDrugError = true);
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      _save();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final drug = _drug;
    if (drug == null) {
      setState(() {
        _showDrugError = true;
        _currentStep = 0;
      });
      final fieldContext = _drugFieldKey.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(fieldContext,
            duration: const Duration(milliseconds: 250));
      }
      return;
    }

    if (widget.scannedDrug != null &&
        (drug.name.trim().isEmpty ||
            drug.strength.trim().isEmpty ||
            drug.dosageForm.trim().isEmpty ||
            drug.unit.trim().isEmpty ||
            drug.unit == 'liều')) {
      _toast(
          'Hãy chọn thuốc có đủ tên, hàm lượng, dạng thuốc và đơn vị từ danh mục.');
      return;
    }

    final controller = MedicationScope.read(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);

    final candidateId = int.tryParse(drug.id);
    if (candidateId != null) {
      final patientId =
          AuthScope.maybeOf(context)?.currentSession?.userId ?? '';
      try {
        final existingIds = controller.medications
            .where((m) => m.isActive)
            .map((m) => int.tryParse(m.catalogId))
            .whereType<int>()
            .toList();

        final checkResult = await controller.checkInteractions(
          patientId: patientId,
          candidateMedicationId: candidateId,
          candidateDoseAmount: _dose,
          candidateDoseUnit: drug.unit.isEmpty ? null : drug.unit,
          medicationIds: existingIds,
        );

        if (checkResult.hasInteractions) {
          if (!mounted) return;
          setState(() => _saving = false);
          final proceed =
              await showInteractionWarningDialog(context, checkResult);
          if (proceed != true) {
            return;
          }
          if (mounted) setState(() => _saving = true);
        } else if (checkResult.isInsufficientData ||
            checkResult.insufficientDataMedications.isNotEmpty) {
          if (!mounted) return;
          setState(() => _saving = false);
          final proceed =
              await showInsufficientDataDialog(context, checkResult);
          if (proceed != true) {
            return;
          }
          if (mounted) setState(() => _saving = true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        final proceed = await showInteractionNetworkErrorDialog(context);
        if (proceed != true) {
          return;
        }
        if (mounted) setState(() => _saving = true);
      }

      // Kiem tra tuong tac thuoc - thuc an / do uong (Task 4.06)
      final foodRepo = widget.foodInteractionRepository ??
          InMemoryFoodInteractionRepository();
      try {
        final foodResult = await foodRepo.checkFoodInteractions(
          patientId: patientId,
          medicationName: drug.name,
          activeIngredient: drug.activeIngredient,
          catalogId: candidateId,
        );

        if (foodResult.hasWarnings) {
          if (!mounted) return;
          setState(() => _saving = false);
          final proceed = await showFoodWarningDialog(context, foodResult);
          if (proceed != true) {
            return;
          }
          if (mounted) setState(() => _saving = true);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        final proceed = await showFoodNetworkErrorDialog(context);
        if (proceed != true) {
          return;
        }
        if (mounted) setState(() => _saving = true);
      }
    }

    final draft = Medication(
      id: '',
      catalogId: drug.id,
      name: drug.name,
      activeIngredient: drug.activeIngredient,
      strength: drug.strength,
      unit: drug.unit,
      dosePerIntake: _dose,
      frequency: _frequency,
      timing: _timing,
      times: _frequency.isAsNeeded ? const [] : _times,
      stockRemaining: int.tryParse(_stockController.text),
      dosageForm: drug.dosageForm.isEmpty ? null : drug.dosageForm,
      maxDosesPerDay: _frequency.isAsNeeded ? _maxDoses : null,
    );
    final Medication created;
    try {
      created = await controller.add(draft, clientUuid: _clientUuid);
    } on MedicationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMedicationFailure(context, failure);
      return;
    }
    await _discardCapture();
    if (mounted) navigator.pop(created);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thông tin đã nhập?'),
        content: const Text(
            'Thuốc này chưa được lưu. Nếu thoát, các thông tin vừa nhập sẽ mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tiếp tục nhập'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Bỏ'),
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

  Future<void> _handleBack() async {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      return;
    }
    if (_dirty) {
      final leave = await _confirmDiscard();
      if (leave && mounted) Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final drug = _drug;
    final inUse = drug != null && MedicationScope.of(context).isInUse(drug.id);
    if (widget.scannedDrug != null && drug != null) {
      return _buildScanSchedule(drug, inUse);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thêm thuốc mới'),
          leading: BackButton(
            onPressed: _handleBack,
          ),
        ),
        body: _buildCurrentStep(drug, inUse),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildCurrentStep(DrugCatalogItem? drug, bool inUse) {
    switch (_currentStep) {
      case 0:
        return _buildStep1SelectDrug(drug, inUse);
      case 1:
        return _buildStep2Schedule(drug!, inUse);
      case 2:
        return _buildStep3Confirm(drug!, inUse);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1SelectDrug(DrugCatalogItem? drug, bool inUse) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        ScanEntryCard(onTap: _openCapture),
        if (_captureBytes case final bytes?) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        bytes,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Ảnh đã sẵn sàng',
                          style: AppTextStyles.bodyStrong),
                    ),
                    IconButton(
                      tooltip: 'Bỏ ảnh',
                      onPressed: _discardCapture,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _openCapture(edit: true),
                      child: const Text('Xem ảnh'),
                    ),
                    TextButton(
                      onPressed: _openCapture,
                      child: const Text('Chụp lại'),
                    ),
                    TextButton(
                      onPressed: _pickDrug,
                      child: const Text('Nhập thủ công'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (kDebugMode && AppPreviewScope.maybeOf(context) != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.drugSelectionDemo),
            child: const Text('Mẫu · Xem thử chọn và xác nhận thuốc'),
          ),
        const SizedBox(height: AppSpacing.xl),
        const OrDivider(label: 'hoặc nhập thủ công'),
        const SizedBox(height: AppSpacing.xl),
        const FormFieldLabel('Thuốc'),
        DrugPickerField(
          key: _drugFieldKey,
          value: drug,
          onTap: _pickDrug,
          errorText: _showDrugError ? 'Vui lòng chọn thuốc từ danh mục' : null,
        ),
        if (inUse) ...[
          const SizedBox(height: AppSpacing.sm),
          CautionNote(
            text: '${drug!.name} đã có trong danh sách đang dùng. '
                'Kiểm tra lại để tránh uống trùng liều.',
          ),
        ] else
          const FormHelperText(
            'Chọn đúng thuốc trong danh mục để DrugTime kiểm tra tương tác chính xác.',
          ),
      ],
    );
  }

  Widget _buildStep2Schedule(DrugCatalogItem drug, bool inUse) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        const FormFieldLabel('Thuốc đã chọn'),
        DrugPickerField(
          key: _drugFieldKey,
          value: drug,
          onTap: _pickDrug,
        ),
        if (inUse) ...[
          const SizedBox(height: AppSpacing.sm),
          CautionNote(
            text: '${drug.name} đã có trong danh sách đang dùng. '
                'Kiểm tra lại để tránh uống trùng liều.',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        // 2. Hàm lượng
        const FormFieldLabel('Hàm lượng'),
        ReadOnlyField(
          value: drug.strength,
          placeholder: 'Tự điền khi chọn thuốc',
        ),
        const SizedBox(height: AppSpacing.xl),

        // 3. Mỗi lần uống
        const FormFieldLabel('Mỗi lần uống'),
        DoseStepper(
          value: _dose,
          unit: drug.unit.isEmpty ? 'viên' : drug.unit,
          min: _dose < 1 ? _dose : 1,
          onChanged: (v) => _update(() => _dose = v),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 4. Tần suất
        const FormFieldLabel('Tần suất'),
        TwoColumnGrid(
          children: [
            for (final f in DoseFrequency.selectable)
              SelectablePill(
                label: f.label,
                selected: f == _frequency,
                onTap: () => _setFrequency(f),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // 5. Giờ uống
        const FormFieldLabel('Giờ uống'),
        if (_frequency.isAsNeeded) ...[
          const InfoNote(
            icon: Icons.notifications_off_outlined,
            text: 'Thuốc dùng khi cần sẽ không có lịch nhắc. '
                'Bạn tự ghi lại mỗi lần uống.',
          ),
          const SizedBox(height: AppSpacing.xl),
          const FormFieldLabel('Tối đa mỗi ngày'),
          DoseStepper(
            key: const ValueKey('max-doses-stepper'),
            value: _maxDoses.toDouble(),
            unit: 'lần/ngày',
            min: minMaxDosesPerDay.toDouble(),
            max: maxMaxDosesPerDay.toDouble(),
            decreaseTooltip: 'Giảm số lần tối đa',
            increaseTooltip: 'Tăng số lần tối đa',
            onChanged: (v) => _update(() => _maxDoses = v.round()),
          ),
          const FormHelperText('Không dùng quá số lần này trong một ngày.'),
        ] else ...[
          TwoColumnGrid(
            children: [
              for (final (i, t) in _times.indexed)
                DoseTimeTile(index: i, time: t, onTap: () => _editTime(i)),
            ],
          ),
          const FormHelperText('Nhấn vào giờ để thay đổi.'),
        ],
        const SizedBox(height: AppSpacing.xl),

        // 6. Cách uống
        const FormFieldLabel('Uống thế nào'),
        IntakeTimingSelector(
          value: _timing,
          onChanged: (v) => _update(() => _timing = v),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 7. Tồn kho
        const FormFieldLabel('Số lượng hiện có', optional: true),
        TextField(
          controller: _stockController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (_) => _dirty = true,
          style: AppTextStyles.figure,
          decoration: InputDecoration(
            hintText: 'Ví dụ: 30',
            suffixText: drug.unit.isEmpty ? 'viên' : drug.unit,
            suffixStyle: AppTextStyles.body,
          ),
        ),
        const FormHelperText('DrugTime sẽ báo khi thuốc sắp hết.'),
      ],
    );
  }

  Widget _buildStep3Confirm(DrugCatalogItem drug, bool inUse) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        Semantics(
          header: true,
          child: const Text('Xác nhận thông tin', style: AppTextStyles.heading),
        ),
        const SizedBox(height: AppSpacing.md),
        ScheduleSummaryCard(
          drug: drug,
          dose: _dose,
          frequency: _frequency,
          times: _times,
          timing: _timing,
          stock: int.tryParse(_stockController.text),
          maxDoses: _maxDoses,
          onEdit: () => setState(() => _currentStep = 1),
        ),
        if (inUse) ...[
          const SizedBox(height: AppSpacing.md),
          CautionNote(
            text: '${drug.name} đã có trong danh sách đang dùng. '
                'Kiểm tra lại để tránh uống trùng liều.',
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_currentStep == 0) {
      return _StepActionBar(
        label: 'Tiếp tục',
        onPressed: _nextStep,
      );
    }
    if (_currentStep == 1) {
      return _StepActionBar(
        label: 'Tiếp tục',
        onPressed: _nextStep,
      );
    }
    return _SaveBar(
      summary: _summary(),
      saving: _saving,
      onSave: _save,
    );
  }

  Widget _buildScanSchedule(DrugCatalogItem drug, bool inUse) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveIfConfirmed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F5),
        appBar: AppBar(
            title: const Text('Lịch uống'),
            centerTitle: true,
            leading: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filled(
                    tooltip: 'Quay lại',
                    style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE3F2EF),
                        foregroundColor: AppColors.brand),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(LucideIcons.chevronLeft))),
            backgroundColor: const Color(0xFFF4F6F5)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Bước 2/3 · Lịch uống',
              style: TextStyle(
                  color: AppColors.brand, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
              children: List.generate(
                  3,
                  (index) => Expanded(
                      child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                          decoration: BoxDecoration(
                              color: index < 2
                                  ? AppColors.brand
                                  : const Color(0xFFE1E5E3),
                              borderRadius: BorderRadius.circular(4)))))),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFEFDF),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: SizedBox.square(
                            dimension: 30,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              Transform.rotate(
                                  angle: -0.785398,
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: const SizedBox(
                                          width: 23,
                                          height: 11,
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                    child: ColoredBox(
                                                        color:
                                                            Color(0xFFFFAC56))),
                                                Expanded(
                                                    child: ColoredBox(
                                                        color:
                                                            Color(0xFFF9FAFA)))
                                              ])))),
                              const Icon(LucideIcons.pill,
                                  size: 30, color: Color(0xFF17396F)),
                            ])))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(drug.name, style: AppTextStyles.bodyStrong),
                      Text(
                          [drug.dosageForm]
                              .where((v) => v.isNotEmpty)
                              .join(' · '),
                          style: AppTextStyles.caption)
                    ])),
                TextButton(
                    onPressed: _pickDrug,
                    style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE4F2EF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Đổi'))
              ])),
          if (inUse)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Thuốc này đã có trong danh sách đang dùng. Hãy kiểm tra để tránh trùng liều.')),
          if (drug.strength.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                    label: Text(drug.strength),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE1E5E3)))),
          ],
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Flexible(
                              child: Text('Mỗi lần uống',
                                  style: AppTextStyles.bodyStrong)),
                          const SizedBox(width: 8),
                          Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F0),
                                  borderRadius: BorderRadius.circular(40)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        tooltip: 'Giảm liều',
                                        onPressed: _dose - 1 >=
                                                (_dose < 1 ? _dose : 1)
                                            ? () => _update(() => _dose -= 1)
                                            : null,
                                        style: IconButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: AppColors.brand,
                                            disabledBackgroundColor:
                                                Colors.white),
                                        icon: const Icon(Icons.remove)),
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Semantics(
                                            liveRegion: true,
                                            child: Text(
                                                '${formatQuantity(_dose)} ${drug.unit}',
                                                style:
                                                    AppTextStyles.bodyStrong))),
                                    IconButton(
                                        tooltip: 'Tăng liều',
                                        onPressed: _dose + 1 <= 10
                                            ? () => _update(() => _dose += 1)
                                            : null,
                                        style: IconButton.styleFrom(
                                            backgroundColor: AppColors.brand,
                                            foregroundColor: Colors.white),
                                        icon: const Icon(Icons.add)),
                                  ])),
                        ]),
                    const Divider(height: 32),
                    const Text('Giờ uống',
                        style: TextStyle(
                            color: Color(0xFF6B737D),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (i, t) in _times.indexed)
                        SizedBox(
                            height: 48,
                            child: InputChip(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                backgroundColor: const Color(0xFFE5F3F0),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                labelStyle: const TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.bold),
                                deleteIconColor: AppColors.brand,
                                label: Text(t.format()),
                                onPressed: () => _editTime(i),
                                onDeleted: _times.length <= 1
                                    ? null
                                    : () => _update(() {
                                          _times = [..._times]..removeAt(i);
                                          _frequency =
                                              DoseFrequency.forTimeCount(
                                                  _times.length);
                                        }))),
                      if (_times.length < 6)
                        SizedBox(
                            height: 48,
                            child: ActionChip(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                label: const Text('+ Thêm giờ'),
                                onPressed: () async {
                                  final selected = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          const TimeOfDay(hour: 12, minute: 0));
                                  if (!mounted || selected == null) return;
                                  final t =
                                      DoseTime(selected.hour, selected.minute);
                                  if (_times.contains(t)) {
                                    _toast('Giờ uống đã tồn tại.');
                                    return;
                                  }
                                  _update(() {
                                    _times = [..._times, t]..sort();
                                    _frequency = DoseFrequency.forTimeCount(
                                        _times.length);
                                  });
                                })),
                    ]),
                    const SizedBox(height: 20),
                    const Text('Uống khi nào',
                        style: TextStyle(
                            color: Color(0xFF6B737D),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final (index, timing)
                          in IntakeTiming.values.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                            child: SizedBox(
                                height: 48,
                                child: ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  showCheckmark: false,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  label: Center(
                                      heightFactor: 1,
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_timing == timing) ...[
                                                  const Icon(Icons.check,
                                                      color: Colors.white,
                                                      size: 17),
                                                  const SizedBox(width: 5)
                                                ],
                                                Text(timing ==
                                                        IntakeTiming.anytime
                                                    ? 'Bất kỳ'
                                                    : timing.label),
                                              ]))),
                                  selected: _timing == timing,
                                  selectedColor: AppColors.brand,
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                          color: Color(0xFFE1E5E3))),
                                  labelStyle: TextStyle(
                                      color: _timing == timing
                                          ? Colors.white
                                          : Colors.black87),
                                  checkmarkColor: Colors.white,
                                  onSelected: (_) =>
                                      _update(() => _timing = timing),
                                ))),
                      ],
                    ]),
                  ])),
        ]),
        bottomNavigationBar: ColoredBox(
            color: Colors.white,
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        icon: const Icon(LucideIcons.arrowRight),
                        label: Text(_saving ? 'Đang lưu…' : 'Tiếp tục'))))),
      ),
    );
  }

  /// Tóm tắt ngay trên nút Lưu để người dùng rà lại trước khi xác nhận.
  String? _summary() {
    final drug = _drug;
    if (drug == null) return null;
    final dose =
        '${formatQuantity(_dose)} ${drug.unit.isEmpty ? "viên" : drug.unit}';
    if (_frequency.isAsNeeded) {
      return '$dose mỗi lần · Khi cần · tối đa $_maxDoses lần/ngày';
    }
    return '$dose · ${_times.map((t) => t.format()).join(', ')} · ${_timing.label}';
  }
}

class _StepActionBar extends StatelessWidget {
  const _StepActionBar({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.summary,
    required this.saving,
    required this.onSave,
  });

  final String? summary;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null) ...[
                Text(
                  summary!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.figureSmall
                      .copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                ),
                child: saving
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onBrand,
                        ),
                      )
                    : const Text('Lưu thuốc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
