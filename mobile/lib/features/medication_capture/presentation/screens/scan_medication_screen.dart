import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../../../medication/domain/entities/dose_unit.dart';
import '../../../medication/domain/entities/medication.dart';
import '../../../medication/presentation/screens/add_medication_screen.dart';
import '../../../medication/presentation/widgets/drug_catalog_sheet.dart';
import '../../data/capture_services.dart';
import '../../domain/capture_models.dart';
import '../../domain/ocr_models.dart';
import '../state/capture_controller.dart';
import '../state/capture_scope.dart';
import '../state/ocr_controller.dart';
import '../widgets/capture_warning_text.dart';
import '../widgets/ocr_single_result_card.dart';
import '../widgets/recognition_steps.dart';
import '../widgets/scan_camera_overlay.dart';
import '../widgets/scan_failure_view.dart';
import '../widgets/scanning_mascot.dart';

/// S07-O: camera, recognition, confirmation and scheduling.
class ScanMedicationScreen extends StatefulWidget {
  const ScanMedicationScreen({super.key});
  @override
  State<ScanMedicationScreen> createState() => _ScanMedicationScreenState();
}

enum _Screen { camera, recognizing, result, failure }

class _ScanMedicationScreenState extends State<ScanMedicationScreen>
    with WidgetsBindingObserver {
  CaptureController? _camera;
  ConsentController? _consent;
  bool _hadConsent = false;
  bool _invalidated = false;
  bool _lockedFailure = false;
  bool _cleanupPending = false;
  ModalRoute<dynamic>? _route;
  CaptureServices? _services;
  OcrController? _ocr;
  OcrCandidate? _candidate;
  Uint8List? _image;
  bool _started = false;
  bool _busy = false;
  bool _retryingGallery = false;
  String _failureTitle = 'Chưa đọc được vỏ hộp';
  int _generation = 0;
  _Screen _screen = _Screen.camera;
  String? _failure;
  // The shown medicine came from low_confidence: ask to compare it with the box.
  bool _checkReminder = false;
  CaptureCropRect? _scanCropRect;

  bool get _isLockedFailure =>
      _invalidated || _lockedFailure || _cleanupPending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _route = ModalRoute.of(context);
    _consent = context.getInheritedWidgetOfExactType<ConsentScope>()?.notifier;
    _hadConsent = _consent?.hasHealthData ?? false;
    _consent?.addListener(_consentChanged);
    _services = CaptureScope.of(context);
    _camera = CaptureController(
      source: _services!.newSource(),
      processor: _services!.processor,
      store: _services!.store,
      session: _services,
    );
    _services!.addListener(_sessionChanged);
    unawaited(_camera!.start());
  }

  void _consentChanged() {
    final granted = _consent?.hasHealthData ?? false;
    final revoked = _hadConsent && !granted;
    _hadConsent = granted;
    if (revoked) _sessionChanged();
  }

  void _sessionChanged() {
    if (_invalidated) return;
    _invalidated = true;
    _lockedFailure = true;
    _generation++;
    _clearImage();
    _candidate = null;
    if (mounted) {
      setState(() {
        _screen = _Screen.failure;
        _failureTitle = 'Phiên đã thay đổi';
        _failure = 'Phiên hoặc quyền truy cập đã thay đổi.';
      });
    }
    unawaited(_leaveInvalidated());
  }

  Future<void> _leaveInvalidated() async {
    final clean = await _closeOcr();
    if (!mounted) return;
    if (!clean) {
      setState(() {
        _lockedFailure = true;
        _cleanupPending = true;
        _failureTitle = 'Chưa dọn được ảnh tạm';
        _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
        _screen = _Screen.failure;
      });
      return;
    }
    final navigator = Navigator.of(context);
    if (_route != null && _route!.isActive) {
      navigator.popUntil((route) => route == _route);
    }
    if (mounted && navigator.canPop()) navigator.pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_camera?.background());
      if (_screen != _Screen.camera) unawaited(_exit());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_camera?.resume());
    }
  }

  void _clearImage() {
    final bytes = _image;
    _image = null;
    if (bytes != null) {
      unawaited(MemoryImage(bytes).evict());
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  void _onOcrChanged() {
    final ocr = _ocr;
    if (!mounted ||
        ocr == null ||
        _screen != _Screen.failure ||
        ocr.stage != OcrStage.failure) {
      return;
    }
    final kind = ocr.failure?.kind;
    if (kind == OcrFailureKind.expiredImage) {
      _clearImage();
      setState(() {
        _failureTitle = 'Ảnh đã hết hạn';
        _failure = ocr.failure!.message;
      });
    } else if (kind == OcrFailureKind.cleanup) {
      _clearImage();
      setState(() {
        _lockedFailure = true;
        _cleanupPending = true;
        _failureTitle = 'Chưa dọn được ảnh tạm';
        _failure = ocr.failure!.message;
      });
    }
  }

  Future<void> _capture({bool gallery = false}) async {
    if (_busy || _isLockedFailure) return;
    _busy = true;
    _failureTitle = 'Chưa đọc được vỏ hộp';
    final generation = ++_generation;
    final camera = _camera!;
    PhotoPickOutcome? pickOutcome;
    if (gallery) {
      pickOutcome = await camera.pickPhoto();
    } else {
      await camera.takePhoto(crop: _scanCropRect);
    }
    if (!mounted || generation != _generation) return;
    if (pickOutcome == PhotoPickOutcome.canceled) {
      setState(() => _busy = false);
      return;
    }
    if (pickOutcome == PhotoPickOutcome.failed || !camera.canUseImage) {
      _busy = false;
      setState(() {
        _failureTitle = gallery ? 'Không mở được ảnh' : 'Không chụp được ảnh';
        final warning = camera.blockingWarning;
        _failure = camera.error ??
            (camera.image == null
                ? 'Không chụp được ảnh. Hãy thử lại.'
                : warning != null
                    ? captureWarningMessage(warning)
                    : 'Ảnh chưa đủ rõ. Hãy chụp lại.');
        _screen = _Screen.failure;
      });
      return;
    }
    final lease = await camera.prepare();
    if (!mounted || generation != _generation) {
      await lease?.release();
      return;
    }
    if (lease == null) {
      _busy = false;
      setState(() {
        _failureTitle = 'Không chuẩn bị được ảnh';
        _failure = camera.error ?? 'Không chuẩn bị được ảnh.';
        _screen = _Screen.failure;
      });
      return;
    }
    camera.takeLease();
    _image =
        camera.image == null ? null : Uint8List.fromList(camera.image!.bytes);
    camera.image = null;
    _ocr = OcrController(image: lease, services: _services!)
      ..addListener(_onOcrChanged);
    setState(() {
      _screen = _Screen.recognizing;
      _failure = null;
    });
    await _ocr!.start();
    await _applyOcrOutcome(generation);
  }

  Future<void> _retryOcr() async {
    if (_busy || _isLockedFailure) return;
    final ocr = _ocr;
    if (ocr == null || !ocr.canRetry) {
      _clearImage();
      setState(() {
        _failureTitle = 'Ảnh đã hết hạn';
        _failure = const OcrFailure(OcrFailureKind.expiredImage).message;
      });
      return;
    }
    _busy = true;
    final generation = ++_generation;
    setState(() {
      _screen = _Screen.recognizing;
      _failure = null;
    });
    await ocr.start();
    await _applyOcrOutcome(generation);
  }

  Future<void> _applyOcrOutcome(int generation) async {
    if (!mounted || generation != _generation) return;
    final result = _ocr?.result;
    final failure = _ocr?.failure;
    // matched and low_confidence: show items[0] for the user to check and confirm
    // (01 §6.1; low_confidence adds a reminder). Never auto-select or auto-add (QD-39).
    if (result != null &&
        result.status != OcrMatchStatus.noMatch &&
        result.items.isNotEmpty) {
      setState(() {
        _candidate = result.items.first;
        _checkReminder = result.status == OcrMatchStatus.lowConfidence;
        _lockedFailure = false;
        _cleanupPending = false;
        _screen = _Screen.result;
        _busy = false;
      });
      return;
    }
    if (failure?.kind == OcrFailureKind.unauthorized) {
      _lockedFailure = true;
      final clean = await _closeOcr();
      _clearImage();
      if (!mounted || generation != _generation) return;
      setState(() {
        _cleanupPending = !clean;
        _failureTitle =
            clean ? 'Phiên đăng nhập đã hết hạn' : 'Chưa dọn được ảnh tạm';
        _failure = clean
            ? failure!.message
            : 'Chưa dọn được ảnh tạm. Hãy thử lại.';
        _screen = _Screen.failure;
        _busy = false;
      });
      return;
    }
    if (failure?.kind == OcrFailureKind.cleanup) {
      _clearImage();
      setState(() {
        _lockedFailure = true;
        _cleanupPending = true;
        _failureTitle = 'Chưa dọn được ảnh tạm';
        _failure = failure!.message;
        _screen = _Screen.failure;
        _busy = false;
      });
      return;
    }
    if (failure?.kind == OcrFailureKind.expiredImage) {
      _clearImage();
      setState(() {
        _failureTitle = 'Ảnh đã hết hạn';
        _failure = failure!.message;
        _screen = _Screen.failure;
        _busy = false;
      });
      return;
    }
    // Nothing to show: ask for the side with the name; manual search is the user's choice
    // (PB31), never opened automatically.
    final noName = result != null || failure?.kind == OcrFailureKind.noText;
    setState(() {
      if (noName) {
        _failureTitle = 'Chưa thấy tên thuốc';
        _failure = 'Hãy chụp mặt có tên thuốc';
      } else {
        _failureTitle = switch (failure?.kind) {
          OcrFailureKind.invalidImage => 'Không mở được ảnh',
          OcrFailureKind.recognition => 'Chưa đọc được vỏ hộp',
          _ => 'Chưa hoàn tất nhận diện',
        };
        _failure =
            failure?.message ?? 'Hãy thử ảnh khác hoặc nhập tay để tìm thuốc.';
      }
      _screen = _Screen.failure;
      _busy = false;
    });
  }

  Future<bool> _closeOcr() async {
    final ocr = _ocr;
    if (ocr == null) {
      if (_cleanupPending && _services != null) {
        final clean = await _services!.retryCleanup();
        if (clean) _cleanupPending = false;
        return clean;
      }
      return true;
    }
    ocr.removeListener(_onOcrChanged);
    var clean = await ocr.close();
    if (!clean) clean = await _services!.retryCleanup();
    if (clean) {
      ocr.dispose();
      _ocr = null;
      _cleanupPending = false;
      _clearImage();
    } else {
      _cleanupPending = true;
    }
    return clean;
  }

  Future<void> _retake() async {
    if (_isLockedFailure) {
      await _exit();
      return;
    }
    _generation++;
    if (!await _closeOcr()) {
      if (mounted) {
        setState(() {
          _lockedFailure = true;
          _cleanupPending = true;
          _failureTitle = 'Chưa dọn được ảnh tạm';
          _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
          _screen = _Screen.failure;
        });
      }
      return;
    }
    _clearImage();
    _candidate = null;
    _busy = false;
    if (!mounted) return;
    setState(() {
      _screen = _Screen.camera;
      _failure = null;
    });
    await _camera?.retake();
  }

  Future<void> _failDuringRecognition() async {
    if (_screen != _Screen.recognizing) return;
    _generation++;
    if (!await _closeOcr()) {
      if (mounted) {
        setState(() {
          _busy = false;
          _lockedFailure = true;
          _cleanupPending = true;
          _failureTitle = 'Chưa dọn được ảnh tạm';
          _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
          _screen = _Screen.failure;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _failureTitle = 'Chưa đọc được vỏ hộp';
        _failure = 'Chưa đọc được vỏ hộp. Hãy quét lại.';
        _screen = _Screen.failure;
      });
    }
  }

  Future<void> _chooseAnotherPhoto() async {
    if (_retryingGallery || _isLockedFailure) return;
    setState(() => _retryingGallery = true);
    try {
      await _retake();
      if (mounted && !_isLockedFailure && _screen == _Screen.camera) {
        await _capture(gallery: true);
      }
    } finally {
      if (mounted) setState(() => _retryingGallery = false);
    }
  }

  Future<void> _exit() async {
    _generation++;
    if (!await _closeOcr()) {
      if (mounted) {
        setState(() {
          _lockedFailure = true;
          _cleanupPending = true;
          _failureTitle = 'Chưa dọn được ảnh tạm';
          _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
          _screen = _Screen.failure;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirm() async {
    final candidate = _candidate;
    if (candidate == null) return;
    final drug = DrugCatalogItem(
      id: candidate.id.toString(),
      name: candidate.name,
      activeIngredient: candidate.activeIngredient ?? '',
      strength: candidate.strengthText ?? '',
      dosageForm: candidate.dosageForm ?? '',
      unit: doseUnitFor(candidate.dosageForm),
    );
    await _openDrug(drug);
  }

  Future<void> _openDrug(DrugCatalogItem drug) async {
    if (!await _closeOcr()) {
      if (mounted) {
        setState(() {
          _lockedFailure = true;
          _cleanupPending = true;
          _failureTitle = 'Chưa dọn được ảnh tạm';
          _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
          _screen = _Screen.failure;
        });
      }
      return;
    }
    _clearImage();
    if (!mounted) return;
    final route = ModalRoute.of(context);
    await Navigator.of(context).push<Medication>(MaterialPageRoute(
      builder: (_) => AddMedicationScreen(scannedDrug: drug),
    ));
    // Lưu xong, màn "Đã thêm thuốc" gỡ cả màn quét khỏi stack: không mở lại camera. Chỉ chụp
    // lại khi người dùng quay về từ bước lịch uống.
    if (mounted && (route?.isActive ?? false)) await _retake();
  }

  Future<void> _manualEntry() async {
    if (_isLockedFailure) return;
    final generation = _generation;
    final drug = await showDrugCatalogSheet(
      context,
      initialQuery: _ocr?.result?.suggestedQuery,
    );
    if (!mounted || drug == null || generation != _generation) return;
    await _openDrug(drug);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _services?.removeListener(_sessionChanged);
    _consent?.removeListener(_consentChanged);
    _ocr?.removeListener(_onOcrChanged);
    _clearImage();
    _ocr?.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final isFailure = _screen == _Screen.failure;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        backgroundColor: isFailure ? AppColors.canvas : AppColors.cameraCanvas,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isFailure: isFailure),
              Expanded(
                child: isFailure
                    ? ScanFailureBody(
                        title: _failureTitle,
                        description:
                            _failure ?? 'Hãy quét lại theo gợi ý bên dưới.',
                      )
                    : LayoutBuilder(builder: (context, constraints) {
                        final showingResult = _screen != _Screen.camera;
                        final viewport = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final frameRect = computeScanFrameRect(viewport);
                        if (!showingResult) {
                          _scanCropRect = toCaptureCropRect(frameRect, viewport);
                        }
                        final frameHeight =
                            (constraints.maxHeight * .38).clamp(120.0, 220.0);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: showingResult
                                  ? const ColoredBox(
                                      color: AppColors.cameraSurface,
                                    )
                                  : _cameraViewport(camera, frameRect),
                            ),
                            if (showingResult)
                              Positioned(
                                top: 48,
                                left: 36,
                                right: 36,
                                height: frameHeight,
                                child: Container(
                                  key: const Key('scan-preview'),
                                  color: AppColors.cameraControl,
                                  child: Center(
                                    child: _image != null
                                        ? Image.memory(
                                            _image!,
                                            fit: BoxFit.contain,
                                            excludeFromSemantics: true,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            if (showingResult)
                              Positioned(
                                top: 48,
                                left: 36,
                                right: 36,
                                height: frameHeight,
                                child: const CustomPaint(
                                  key: Key('scan-frame'),
                                  painter: ScanCornersPainter(),
                                ),
                              ),
                            if (_screen == _Screen.recognizing)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _failDuringRecognition,
                                ),
                              ),
                            if (_screen == _Screen.recognizing ||
                                _screen == _Screen.result)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: GestureDetector(
                                  key: _screen == _Screen.recognizing
                                      ? const Key('scan-recognizing')
                                      : null,
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _screen == _Screen.recognizing
                                      ? _failDuringRecognition
                                      : null,
                                  // Below the photo on normal phones; on very
                                  // short screens it may cover part of the photo
                                  // so the pinned buttons always fit.
                                  child: _resultSheet(math.min(
                                    constraints.maxHeight,
                                    math.max(
                                      _minResultSheetHeight,
                                      math.max(
                                        constraints.maxHeight * .5,
                                        constraints.maxHeight -
                                            48 -
                                            frameHeight -
                                            8,
                                      ),
                                    ),
                                  )),
                                ),
                              ),
                          ],
                        );
                      }),
              ),
              if (_screen == _Screen.camera) _cameraActions(),
              if (isFailure)
                ListenableBuilder(
                  listenable: _ocr ?? _empty,
                  builder: (_, __) => ScanFailureActions(
                    isLockedFailure: _isLockedFailure,
                    cleanupPending: _cleanupPending,
                    canRetry: _ocr?.canRetry ?? false,
                    busy: _retryingGallery || _busy,
                    onRetry: _retryOcr,
                    onManualEntry: _manualEntry,
                    onChooseAnother: _chooseAnotherPhoto,
                    onRetake: _retake,
                    onExit: _exit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isFailure}) {
    final stepLabel = switch (_screen) {
      _Screen.failure => 'Bước 1/3 · Chưa đọc được',
      _Screen.recognizing => 'Bước 1/3 · Đang đọc vỏ hộp',
      _Screen.result => 'Bước 1/3 · Đã nhận diện',
      _Screen.camera => 'Bước 1/3 · Quét vỏ',
    };
    final activeColor = isFailure ? AppColors.brand : AppColors.cameraAccent;
    final inactiveColor =
        isFailure ? AppColors.border : AppColors.cameraOutline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: AppSizes.tapTarget),
              Expanded(
                child: Text(
                  'Quét vỏ thuốc',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isFailure ? AppColors.ink : AppColors.onCamera,
                  ),
                ),
              ),
              IconButton(
                key: const Key('scan-close-button'),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.brandTint,
                  foregroundColor: AppColors.brand,
                  fixedSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
                ),
                onPressed: _exit,
                icon: const Icon(LucideIcons.x),
                tooltip: 'Đóng',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            stepLabel,
            key: const Key('scan-step-label'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.captionStrong.copyWith(color: activeColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 7),
                  decoration: BoxDecoration(
                    color: index == 0 ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraViewport(CaptureController? camera, Rect? frameRect) {
    if (camera == null) {
      return const ColoredBox(color: AppColors.cameraSurface);
    }
    return ListenableBuilder(
      listenable: camera,
      builder: (_, __) {
        final showCameraIssue =
            camera.permissionStatus == CapturePermission.denied ||
                camera.permissionStatus ==
                    CapturePermission.permanentlyDenied ||
                camera.error != null;
        if (showCameraIssue) {
          return ColoredBox(
            color: AppColors.cameraCanvas,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: _cameraIssueCard(camera),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            if (camera.source.ready)
              camera.source.preview()
            else if (camera.stage == CaptureStage.reviewing ||
                camera.stage == CaptureStage.prepared)
              const ColoredBox(
                color: AppColors.cameraSurface,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.cameraAccent,
                  ),
                ),
              )
            else
              ColoredBox(
                color: AppColors.cameraSurface,
                child: Center(
                  child: Text(
                    'Đang mở camera…',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.onCamera,
                    ),
                  ),
                ),
              ),
            if (frameRect != null) ScanCameraOverlay(frameRect: frameRect),
          ],
        );
      },
    );
  }

  Widget _cameraIssueCard(CaptureController camera) {
    final isPermanent =
        camera.permissionStatus == CapturePermission.permanentlyDenied;
    final headline = camera.error ??
        (isPermanent
            ? 'Camera đang bị tắt trong cài đặt'
            : 'Chưa có quyền mở camera');
    return Container(
      key: const Key('scan-camera-issue'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.cameraSurface,
        border: Border.all(color: AppColors.cameraOutline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.cameraOff,
            size: 36,
            color: AppColors.cameraAccent,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(color: AppColors.onCamera),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bạn vẫn có thể chọn ảnh từ Thư viện hoặc Nhập tay ở bên dưới.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.cameraMuted),
          ),
          if (isPermanent) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cameraAccent,
                  foregroundColor: AppColors.onCameraAccent,
                  minimumSize: const Size.fromHeight(AppSizes.tapTarget),
                ),
                onPressed: camera.busy ? null : camera.openSettings,
                child: const Text('Mở cài đặt'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cameraActions() => ListenableBuilder(
        listenable: _camera ?? _empty,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.cameraControl,
                            foregroundColor: AppColors.onCamera,
                            fixedSize: const Size(
                              AppSizes.primaryButton,
                              AppSizes.primaryButton,
                            ),
                          ),
                          onPressed: _camera?.busy == false
                              ? () => _capture(gallery: true)
                              : null,
                          icon: const Icon(LucideIcons.image),
                          tooltip: 'Thư viện',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Thư viện',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onCamera,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: _camera?.source.ready == true &&
                            _camera?.busy == false
                        ? _capture
                        : null,
                    tooltip: 'Chụp ảnh',
                    padding: EdgeInsets.zero,
                    icon: Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.onCamera,
                          width: 3,
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.onCamera,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      children: [
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.cameraControl,
                            foregroundColor: AppColors.onCamera,
                            fixedSize: const Size(
                              AppSizes.primaryButton,
                              AppSizes.primaryButton,
                            ),
                          ),
                          onPressed: _manualEntry,
                          tooltip: 'Nhập tay',
                          icon: const Icon(LucideIcons.pencil),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nhập tay',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onCamera,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Ảnh chỉ xử lý trên điện thoại của bạn',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.cameraMuted,
                ),
              ),
            ],
          ),
        ),
      );

  static final ChangeNotifier _empty = ChangeNotifier();

  /// [maxHeight] keeps the sheet below the photo so the box stays visible
  /// while the user compares it with the one result. Only the card scrolls: the
  /// buttons stay pinned at the bottom of the sheet (adhoc-20261120 nhận xét 2).
  Widget _resultSheet(double maxHeight) => Container(
        key: const Key('scan-result-sheet'),
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: _screen == _Screen.recognizing
            ? SingleChildScrollView(child: _recognizingContent())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 14),
                  const Text(
                    'Có đúng thuốc trên vỏ hộp không?',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const Key('scan-result-scroll'),
                      child: _candidate == null
                          ? const SizedBox.shrink()
                          : OcrSingleResultCard(
                              candidate: _candidate!,
                              strengthUnverified: _ocr?.result?.reasons
                                      .contains('strength_unverified') ??
                                  false,
                              checkReminder: _checkReminder,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_candidate != null)
                    OcrResultActions(
                      onConfirm: _confirm,
                      onNotThis: _manualEntry,
                      onRetake: _retake,
                    )
                  else
                    TextButton(
                      onPressed: _retake,
                      child: const Text('Chụp lại'),
                    ),
                ],
              ),
      );

  /// Title + the three pinned buttons + a little of the card.
  static const double _minResultSheetHeight = 340;

  Widget _sheetHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  /// Steps share one style and the bar follows the real OCR stage (nhận xét 1).
  Widget _recognizingContent() => ListenableBuilder(
        listenable: _ocr ?? _empty,
        builder: (_, __) {
          final stage = _ocr?.stage ?? OcrStage.recognizing;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const ScanningMascot(size: 72),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Đang nhận diện thuốc...',
                      style: AppTextStyles.title.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: recognitionProgress(stage)),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  builder: (_, value, __) => LinearProgressIndicator(
                    key: const Key('scan-progress'),
                    value: value,
                    minHeight: 7,
                    color: AppColors.brand,
                    backgroundColor: AppColors.brandTint,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              RecognitionSteps(stage: stage),
              const SizedBox(height: AppSpacing.xs),
              Container(
                key: const Key('scan-privacy-banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.shield,
                      size: 18,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ảnh chỉ xử lý trên máy, không gửi đi',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}
