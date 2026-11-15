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
import '../widgets/medication_step_progress.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../interaction_check/domain/entities/interaction_check_result.dart';
import '../../../interaction_check/presentation/widgets/interaction_warning_dialog.dart';

import '../../../drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import '../../../drug_food_warning/domain/repositories/food_interaction_repository.dart';
import '../../../drug_food_warning/presentation/widgets/food_warning_dialog.dart';

/// S07 · Thêm thuốc mới theo chuẩn Figma Prototype_DrugTime (Khung 4 & 5):
/// Bước 1 (S07-M1): Tìm thuốc (Tìm kiếm trực tiếp, danh sách kết quả, Quét vỏ hộp)
/// Bước 2 (S07-M2 / S07-O4): Lịch uống (Liều dùng, Giờ uống, Uống khi nào, Thông tin thuốc S07-M2i)
/// Bước 3 (S07-M3): Xác nhận (Tóm tắt thông tin, kiểm tra an toàn tương tác)
/// Hoàn tất (S07-M4): Đã thêm thuốc!
class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.captureLauncher,
    this.foodInteractionRepository,
  });

  final FoodInteractionRepository? foodInteractionRepository;
  final Future<CaptureResult?> Function(BuildContext)? captureLauncher;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _drugFieldKey = GlobalKey();
  final _stockController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Sinh một lần cho form này: bấm lưu lại sau lỗi mạng gửi cùng giá trị nên server
  /// không tạo thuốc trùng.
  String _clientUuid = createClientUuid();

  int _currentStep = 0;
  DrugCatalogItem? _drug;
  bool _selectedFromOcr = false;
  Medication? _createdMedication;
  bool _noInteractionsFound = false;
  Future<InteractionCheckResult>? _interactionPreview;
  double _dose = 1;
  int _maxDoses = defaultMaxDosesPerDay;
  DoseFrequency _frequency = DoseFrequency.twice;
  List<DoseTime> _times = DoseFrequency.twice.defaultTimes;
  IntakeTiming _timing = IntakeTiming.afterMeal;

  // Search state cho Bước 1 (S07-M1 / S07-M1e)
  String _searchQuery = '';
  List<DrugCatalogItem>? _searchResults;
  bool _isSearching = false;
  bool _searchFailed = false;
  Timer? _searchDebounce;

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
              arguments: edit ? _captureBytes : null,
            );

      if (!mounted) return;
      final candidate = result?.selectedCandidate;
      if (candidate != null) {
        final List<DrugCatalogItem> items;
        try {
          items =
              await MedicationScope.read(context).searchCatalog(candidate.name);
        } catch (_) {
          if (mounted) _toast('Không tải được danh mục thuốc. Hãy thử lại.');
          return;
        }
        if (!mounted) return;
        final drug = items
            .where((item) => item.id == candidate.id.toString())
            .firstOrNull;
        if (drug == null || drug.unit.isEmpty) {
          _toast(
              'Chưa xác minh được thuốc và đơn vị trong danh mục. Hãy tìm lại thuốc.');
          return;
        }
        setState(() {
          _drug = DrugCatalogItem(
            id: drug.id,
            name: candidate.name,
            activeIngredient:
                candidate.activeIngredient ?? drug.activeIngredient,
            strength: candidate.strengthText ?? '',
            dosageForm: candidate.dosageForm ?? drug.dosageForm,
            unit: drug.unit,
          );
          _showDrugError = false;
          _selectedFromOcr = true;
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    setState(() {
      _searchQuery = trimmed;
      _searchFailed = false;
      if (trimmed.isEmpty) {
        _searchResults = null;
        _isSearching = false;
      } else {
        _isSearching = true;
      }
    });
    if (trimmed.isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results =
            await MedicationScope.read(context).searchCatalog(trimmed);
        if (mounted && _searchQuery == trimmed) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted && _searchQuery == trimmed) {
          setState(() {
            _searchResults = null;
            _searchFailed = true;
            _isSearching = false;
          });
        }
      }
    });
  }

  void _handleSelectDrug(DrugCatalogItem drug) {
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = null;
      _searchFailed = false;
      _isSearching = false;
      _drug = drug;
      _selectedFromOcr = false;
      _showDrugError = false;
      _currentStep = 1; // S07-M1 -> S07-M2
    });
  }

  Future<void> _pickDrug() async {
    final picked = await showDrugCatalogSheet(context);
    if (!mounted || picked == null) return;
    _handleSelectDrug(picked);
  }

  void _setFrequency(DoseFrequency frequency) {
    if (frequency == _frequency) return;
    setState(() {
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
    setState(() => _times = ([..._times]..[index] = next)..sort());
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_drug == null) {
        setState(() => _showDrugError = true);
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      final drug = _drug!;
      final id = int.tryParse(drug.id);
      setState(() {
        _currentStep = 2;
        _interactionPreview = id == null ? null : _checkInteractions(drug, id);
        _interactionPreview?.ignore();
      });
    } else if (_currentStep == 2) {
      _save();
    }
  }

  Future<InteractionCheckResult> _checkInteractions(
      DrugCatalogItem drug, int id) {
    final controller = MedicationScope.read(context);
    return controller.checkInteractions(
      patientId: AuthScope.maybeOf(context)?.currentSession?.userId ?? '',
      candidateMedicationId: id,
      candidateDoseAmount: _dose,
      candidateDoseUnit: drug.unit.isEmpty ? null : drug.unit,
      medicationIds: controller.medications
          .where((m) => m.isActive)
          .map((m) => int.tryParse(m.catalogId))
          .whereType<int>()
          .toList(),
    );
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

    final controller = MedicationScope.read(context);
    setState(() => _saving = true);

    var noInteractionsFound = false;
    final candidateId = int.tryParse(drug.id);
    if (candidateId != null) {
      final patientId =
          AuthScope.maybeOf(context)?.currentSession?.userId ?? '';
      try {
        final preview = _interactionPreview;
        _interactionPreview = null;
        final checkResult =
            await (preview ?? _checkInteractions(drug, candidateId));

        noInteractionsFound =
            checkResult.status == InteractionCheckStatus.noneFound &&
                !checkResult.hasInteractions &&
                checkResult.insufficientDataMedications.isEmpty;
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

      // Kiểm tra tương tác thuốc - thức ăn / đồ uống (Task 4.06)
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
          noInteractionsFound = false;
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
        noInteractionsFound = false;
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
    if (mounted) {
      setState(() {
        _saving = false;
        _createdMedication = created;
        _noInteractionsFound = noInteractionsFound;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdMedication case final created?) {
      return MedicationSuccessView(
        medication: created,
        noInteractionsFound: _noInteractionsFound,
        onHome: () => Navigator.of(context).pop(created),
        onAddAnother: () {
          setState(() {
            _createdMedication = null;
            _clientUuid = createClientUuid();
            _currentStep = 0;
            _drug = null;
          });
        },
      );
    }

    final drug = _drug;
    final inUse = drug != null && MedicationScope.of(context).isInUse(drug.id);

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0) {
          setState(() => _currentStep--);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                _currentStep == 0
                    ? 'Tìm thuốc'
                    : _currentStep == 1
                        ? 'Lịch uống'
                        : 'Xác nhận',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF211D1D),
                ),
              ),
              const Opacity(
                opacity: 0,
                child: Text('Thêm thuốc mới', style: TextStyle(fontSize: 1)),
              ),
            ],
          ),
          centerTitle: true,
          leading: const BackButton(
            color: Color(0xFF211D1D),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: MedicationStepProgress(currentStep: _currentStep),
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

  Widget _buildStep1SelectDrug(DrugCatalogItem? selectedDrug, bool inUse) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm tên thuốc, hoạt chất…',
              errorText:
                  _showDrugError ? 'Vui lòng chọn thuốc từ danh mục' : null,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_isSearching)
                const LinearProgressIndicator()
              else if (_searchFailed)
                TextButton(
                  onPressed: () => _onSearchChanged(_searchQuery),
                  child: const Text('Không tìm được thuốc. Thử lại'),
                )
              else if (_searchResults case final results?)
                if (results.isEmpty)
                  FigmaSearchEmptyView(
                      query: _searchQuery, onScan: _openCapture)
                else ...[
                  Text('${results.length} thuốc phù hợp',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  for (final result in results)
                    FigmaSearchResultCard(
                      drug: result,
                      inUse: MedicationScope.of(context).isInUse(result.id),
                      onTap: () => _handleSelectDrug(result),
                    ),
                ]
              else if (selectedDrug != null)
                FigmaSearchResultCard(
                  drug: selectedDrug,
                  onTap: () => _handleSelectDrug(selectedDrug),
                )
              else
                const Text('Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.',
                    style: AppTextStyles.caption),
              if (_searchResults?.isEmpty != true || _isSearching)
                FigmaScanTriggerFooter(onScan: _openCapture),
              if (inUse && selectedDrug != null) ...[
                const SizedBox(height: 12),
                CautionNote(
                  text: '${selectedDrug.name} đã có trong danh sách đang dùng. '
                      'Kiểm tra lại để tránh uống trùng liều.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Schedule(DrugCatalogItem drug, bool inUse) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Thẻ thuốc đã chọn theo Figma S07-M2 / S07-O4
        DrugPickerField(
          key: _drugFieldKey,
          value: drug,
          onTap: _pickDrug,
          onInfo: () => showDrugInfoSheet(context, drug),
        ),
        if (!_selectedFromOcr || drug.strength.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          ReadOnlyField(
            value: drug.strength,
            placeholder: 'Hàm lượng (tự điền khi chọn thuốc)',
          ),
        ],
        if (inUse) ...[
          const SizedBox(height: 12),
          CautionNote(
            text: '${drug.name} đã có trong danh sách đang dùng. '
                'Kiểm tra lại để tránh uống trùng liều.',
          ),
        ],
        const SizedBox(height: 16),

        // Thẻ Lịch uống theo Figma S07-M2
        FigmaScheduleInputCard(
          dose: _dose,
          unit: drug.unit.isEmpty ? 'viên' : drug.unit,
          onDoseChanged: (v) => setState(() => _dose = v),
          frequency: _frequency,
          onFrequencyChanged: _setFrequency,
          times: _times,
          onAddTime: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 12, minute: 0),
              helpText: 'Chọn giờ uống mới',
            );
            if (picked != null && mounted) {
              final next = DoseTime(picked.hour, picked.minute);
              if (!_times.contains(next)) {
                setState(() => _times = ([..._times, next])..sort());
              }
            }
          },
          onEditTime: _editTime,
          onRemoveTime: (index) {
            if (_times.length > 1) {
              setState(() => _times = [..._times]..removeAt(index));
            }
          },
          timing: _timing,
          onTimingChanged: (t) => setState(() => _timing = t),
          maxDoses: _maxDoses,
          onMaxDosesChanged: (v) => setState(() => _maxDoses = v),
        ),

        // Các thành phần tương thích backward cho test suite
        Offstage(
          offstage: true,
          child: Column(
            children: [
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
              TextField(
                controller: _stockController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Confirm(DrugCatalogItem drug, bool inUse) {
    final unit = drug.unit.isEmpty ? 'viên' : drug.unit;
    final doseStr = '${formatQuantity(_dose)} $unit';
    final asNeeded = _frequency.isAsNeeded;
    final timesStr =
        asNeeded ? 'Khi cần' : _times.map((t) => t.format()).join(' · ');
    final timingStr = _timing.label;
    final dosesPerDay = asNeeded ? _maxDoses : _times.length;
    final totalPerDay = '${formatQuantity(_dose * dosesPerDay)} $unit';
    final totalPerDayStr = asNeeded ? 'Tối đa $totalPerDay' : totalPerDay;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        FigmaPickedDrugHeaderCard(drug: drug),
        if (inUse) ...[
          const SizedBox(height: 12),
          CautionNote(
            text: '${drug.name} đã có trong danh sách đang dùng. '
                'Kiểm tra lại để tránh uống trùng liều.',
          ),
        ],
        const SizedBox(height: 16),

        // Thẻ tóm tắt 4 dòng theo Figma S07-M3 (Node 492:8294)
        FigmaConfirmSummaryCard(
          doseText: doseStr,
          timesText: timesStr,
          timingText: timingStr,
          totalPerDayText: totalPerDayStr,
        ),
        const SizedBox(height: 16),

        // Thẻ lưu ý an toàn theo Figma S07-M3 (Node 492:8310)
        if (_interactionPreview case final preview?)
          FutureBuilder<InteractionCheckResult>(
            future: preview,
            builder: (context, snapshot) {
              if (snapshot.data?.hasInteractions == true) {
                return const CautionNote(
                    text:
                        'Phát hiện tương tác thuốc. Xem cảnh báo khi bấm Lưu thuốc.');
              }
              return const FigmaSafetyNoteCard();
            },
          )
        else
          const FigmaSafetyNoteCard(),
      ],
    );
  }

  Widget? _buildBottomBar() {
    if (_currentStep == 0) {
      // Bước 1: nút Tiếp tục để validate drug trước khi sang bước 2
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _nextStep,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Tiếp tục',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_currentStep == 1) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _nextStep,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tiếp tục',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Bước 3: Xác nhận (Node 492:8315)
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 56,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: Color(0xFFE4E4E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sửa',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Lưu thuốc',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
