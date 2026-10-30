import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

/// S07 · Thêm thuốc mới (Figma node 33:4419).
///
/// Trả về [Medication] vừa lưu qua `Navigator.pop` để màn trước xác nhận.
class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key, this.captureLauncher});
  final Future<CaptureResult?> Function(BuildContext)? captureLauncher;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _drugFieldKey = GlobalKey();
  final _stockController = TextEditingController();

  /// Sinh một lần cho form này: bấm lưu lại sau lỗi mạng gửi cùng giá trị nên server
  /// không tạo thuốc trùng.
  final String _clientUuid = createClientUuid();

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
              arguments: edit ? _captureBytes : null);
      if (result?.kind == CaptureResultKind.prepared && result?.image != null) {
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

  Future<void> _save() async {
    // Nút chỉ bị vô hiệu ở frame sau; chặn lần nhấn thứ hai trong lúc đang lưu.
    if (_saving) return;
    final drug = _drug;
    if (drug == null) {
      setState(() => _showDrugError = true);
      final fieldContext = _drugFieldKey.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(fieldContext,
            duration: const Duration(milliseconds: 250));
      }
      return;
    }

    final controller = MedicationScope.read(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);

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
      // Giữ nguyên form để người dùng lưu lại; lần sau dùng cùng _clientUuid.
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

  @override
  Widget build(BuildContext context) {
    final drug = _drug;
    final inUse = drug != null && MedicationScope.of(context).isInUse(drug.id);

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveIfConfirmed();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Thêm thuốc mới')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            Material(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(AppRadius.card),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: _openCapture,
                    child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(children: [
                          Icon(Icons.document_scanner_outlined,
                              color: AppColors.brand, size: 32),
                          SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Quét vỏ thuốc',
                                    style: AppTextStyles.bodyStrong),
                                SizedBox(height: 4),
                                Text('Chụp hộp hoặc vỉ thuốc',
                                    style: AppTextStyles.caption)
                              ])),
                          Icon(Icons.chevron_right, color: AppColors.brand)
                        ])))),
            if (_captureBytes case final bytes?) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: BorderRadius.circular(AppRadius.card)),
                  child: Column(children: [
                    Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(bytes,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true)),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('Ảnh đã sẵn sàng',
                              style: AppTextStyles.bodyStrong)),
                      IconButton(
                          tooltip: 'Bỏ ảnh',
                          onPressed: _discardCapture,
                          icon: const Icon(Icons.close)),
                    ]),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: () => _openCapture(edit: true),
                          child: const Text('Xem ảnh')),
                      TextButton(
                          onPressed: _openCapture,
                          child: const Text('Chụp lại')),
                      TextButton(
                          onPressed: _pickDrug,
                          child: const Text('Nhập thủ công'))
                    ])
                  ])),
            ],
            if (kDebugMode && AppPreviewScope.maybeOf(context) != null)
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRoutes.drugSelectionDemo),
                child: const Text('Mẫu · Xem thử chọn và xác nhận thuốc'),
              ),
            ScanEntryCard(
                onTap: () => _toast('Quét vỏ thuốc đang được phát triển')),
            const SizedBox(height: AppSpacing.xl),
            const OrDivider(label: 'hoặc nhập thủ công'),
            const SizedBox(height: AppSpacing.xl),

            // 1. Thuốc
            const FormFieldLabel('Thuốc'),
            DrugPickerField(
              key: _drugFieldKey,
              value: drug,
              onTap: _pickDrug,
              errorText:
                  _showDrugError ? 'Vui lòng chọn thuốc từ danh mục' : null,
            ),
            if (inUse) ...[
              const SizedBox(height: AppSpacing.sm),
              CautionNote(
                text: '${drug.name} đã có trong danh sách đang dùng. '
                    'Kiểm tra lại để tránh uống trùng liều.',
              ),
            ] else
              const FormHelperText(
                'Chọn đúng thuốc trong danh mục để DrugTime kiểm tra tương tác chính xác.',
              ),
            const SizedBox(height: AppSpacing.xl),

            // 2. Hàm lượng
            const FormFieldLabel('Hàm lượng'),
            ReadOnlyField(
                value: drug?.strength, placeholder: 'Tự điền khi chọn thuốc'),
            const SizedBox(height: AppSpacing.xl),

            // 3. Liều mỗi lần
            const FormFieldLabel('Mỗi lần uống'),
            DoseStepper(
              value: _dose,
              unit: drug?.unit ?? 'viên',
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
                suffixText: drug?.unit ?? 'viên',
                suffixStyle: AppTextStyles.body,
              ),
            ),
            const FormHelperText('DrugTime sẽ báo khi thuốc sắp hết.'),
          ],
        ),
        bottomNavigationBar: _SaveBar(
          summary: _summary(),
          saving: _saving,
          onSave: _save,
        ),
      ),
    );
  }

  /// Tóm tắt ngay trên nút Lưu để người dùng rà lại trước khi xác nhận.
  String? _summary() {
    final drug = _drug;
    if (drug == null) return null;
    final dose = '${formatQuantity(_dose)} ${drug.unit}';
    if (_frequency.isAsNeeded) {
      return '$dose mỗi lần · Khi cần · tối đa $_maxDoses lần/ngày';
    }
    return '$dose · ${_times.map((t) => t.format()).join(', ')} · ${_timing.label}';
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar(
      {required this.summary, required this.saving, required this.onSave});

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
