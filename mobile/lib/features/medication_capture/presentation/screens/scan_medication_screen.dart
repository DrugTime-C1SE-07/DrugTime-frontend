import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../widgets/scanning_mascot.dart';

/// S07-O: camera, recognition, confirmation and scheduling.
class ScanMedicationScreen extends StatefulWidget {
  const ScanMedicationScreen({super.key});
  @override
  State<ScanMedicationScreen> createState() => _ScanMedicationScreenState();
}

class _ScanCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF76DACC)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const length = 26.0;
    for (final point in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height)
    ]) {
      final dx = point.dx == 0 ? length : -length;
      final dy = point.dy == 0 ? length : -length;
      canvas.drawLine(point, point + Offset(dx, 0), paint);
      canvas.drawLine(point, point + Offset(0, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanBeam extends StatefulWidget {
  const _ScanBeam();

  static const int _cycles = 30;
  static const period = Duration(milliseconds: 1400);

  @override
  State<_ScanBeam> createState() => _ScanBeamState();
}

class _ScanBeamState extends State<_ScanBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _ScanBeam.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.repeat(reverse: true, count: _ScanBeam._cycles * 2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Align(
          key: const Key('scan-beam'),
          alignment: Alignment(0, -1 + 2 * t),
          child: child,
        );
      },
      child: Container(
        height: 2,
        color: const Color(0xFF76DACC),
      ),
    );
  }
}

enum _Screen { camera, recognizing, result, failure }

class _ScanMedicationScreenState extends State<ScanMedicationScreen>
    with WidgetsBindingObserver {
  CaptureController? _camera;
  ConsentController? _consent;
  bool _hadConsent = false;
  bool _invalidated = false;
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
  // The last scan read no usable medicine name: offer manual search next to retake.
  bool _nameMissed = false;
  // The shown medicine came from low_confidence: ask to compare it with the box.
  bool _checkReminder = false;
  CaptureCropRect? _scanCropRect;

  static const double _cameraFrameMargin = 36;
  static const double _cameraFrameHeight = 220;

  CaptureCropRect? _computeScanCropRect(double vw, double vh) {
    if (vw <= 0 || vh <= 0) return null;
    final frameW = (vw - _cameraFrameMargin * 2).clamp(0.0, vw);
    final frameH = math.min(_cameraFrameHeight, vh);
    if (frameW <= 0 || frameH <= 0) return null;
    return CaptureCropRect(
      left: ((vw - frameW) / 2) / vw,
      top: ((vh - frameH) / 2) / vh,
      width: frameW / vw,
      height: frameH / vh,
      viewportAspectRatio: vw / vh,
    );
  }

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
        session: _services);
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
    _generation++;
    _clearImage();
    _candidate = null;
    if (mounted) {
      setState(() {
        _screen = _Screen.failure;
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

  Future<void> _capture({bool gallery = false}) async {
    if (_busy) return;
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
    _ocr = OcrController(image: lease, services: _services!);
    setState(() {
      _screen = _Screen.recognizing;
      _failure = null;
    });
    await _ocr!.start();
    if (!mounted || generation != _generation) return;
    final result = _ocr!.result;
    final failure = _ocr?.failure;
    // matched and low_confidence: show items[0] for the user to check and confirm
    // (01 §6.1; low_confidence adds a reminder). Never auto-select or auto-add (QD-39).
    if (result != null &&
        result.status != OcrMatchStatus.noMatch &&
        result.items.isNotEmpty) {
      setState(() {
        _candidate = result.items.first;
        _checkReminder = result.status == OcrMatchStatus.lowConfidence;
        _screen = _Screen.result;
        _busy = false;
      });
      return;
    }
    // Nothing to show: ask for the side with the name; manual search is the user's choice
    // (PB31), never opened automatically.
    final noName = result != null || failure?.kind == OcrFailureKind.noText;
    setState(() {
      _nameMissed = noName;
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
    if (ocr == null) return true;
    var clean = await ocr.close();
    if (!clean) clean = await _services!.retryCleanup();
    if (clean) {
      ocr.dispose();
      _ocr = null;
      _clearImage();
    }
    return clean;
  }

  Future<void> _retake() async {
    if (_invalidated) {
      await _leaveInvalidated();
      return;
    }
    _generation++;
    if (!await _closeOcr()) {
      if (mounted) {
        setState(() => _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.');
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
          _failure = 'Chưa dọn được ảnh tạm. Hãy thử lại.';
          _screen = _Screen.failure;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _failure = 'Chưa đọc được vỏ hộp. Hãy quét lại.';
        _screen = _Screen.failure;
      });
    }
  }

  Future<void> _chooseAnotherPhoto() async {
    if (_retryingGallery) return;
    setState(() => _retryingGallery = true);
    try {
      await _retake();
      if (mounted && !_invalidated && _screen == _Screen.camera) {
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
        unit: doseUnitFor(candidate.dosageForm));
    await _openDrug(drug);
  }

  Future<void> _openDrug(DrugCatalogItem drug) async {
    if (!await _closeOcr()) {
      if (mounted) {
        setState(() {
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
        builder: (_) => AddMedicationScreen(scannedDrug: drug)));
    // Lưu xong, màn "Đã thêm thuốc" gỡ cả màn quét khỏi stack: không mở lại camera. Chỉ chụp
    // lại khi người dùng quay về từ bước lịch uống.
    if (mounted && (route?.isActive ?? false)) await _retake();
  }

  Future<void> _manualEntry() async {
    final generation = _generation;
    final drug = await showDrugCatalogSheet(context,
        initialQuery: _ocr?.result?.suggestedQuery);
    if (!mounted || drug == null || generation != _generation) return;
    await _openDrug(drug);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _services?.removeListener(_sessionChanged);
    _consent?.removeListener(_consentChanged);
    _clearImage();
    _ocr?.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
          backgroundColor: _screen == _Screen.failure
              ? const Color(0xFFF4F6F5)
              : const Color(0xFF101111),
          body: SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                    height: 112,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Spacer(),
                            Text('Quét vỏ thuốc',
                                style: TextStyle(
                                    color: _screen == _Screen.failure
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton.filledTonal(
                                onPressed: _exit,
                                icon: const Icon(LucideIcons.x),
                                tooltip: 'Đóng')
                          ]),
                          const SizedBox(height: 8),
                          Text(
                              _screen == _Screen.failure
                                  ? 'Bước 1/3 · Chưa đọc được'
                                  : _screen == _Screen.recognizing
                                      ? 'Bước 1/3 · Đang đọc vỏ hộp'
                                      : _screen == _Screen.result
                                          ? 'Bước 1/3 · Đã nhận diện'
                                          : 'Bước 1/3 · Quét vỏ',
                              style: const TextStyle(
                                  color: Color(0xFF70D9CC),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                              children: List.generate(
                                  3,
                                  (index) => Expanded(
                                      child: Container(
                                          height: 5,
                                          margin: EdgeInsets.only(
                                              right: index == 2 ? 0 : 7),
                                          decoration: BoxDecoration(
                                              color: index == 0
                                                  ? (_screen == _Screen.failure
                                                      ? const Color(0xFF00534D)
                                                      : const Color(0xFF70D9CC))
                                                  : (_screen == _Screen.failure
                                                      ? const Color(0xFFE0E3E1)
                                                      : const Color(
                                                          0xFF505454)),
                                              borderRadius:
                                                  BorderRadius.circular(8)))))),
                        ]))),
            Expanded(
                child: _screen == _Screen.failure
                    ? _failureBody()
                    : LayoutBuilder(builder: (context, constraints) {
                        final showingResult = _screen != _Screen.camera;
                        if (!showingResult) {
                          _scanCropRect = _computeScanCropRect(
                              constraints.maxWidth, constraints.maxHeight);
                        }
                        final frameHeight =
                            (constraints.maxHeight * .38).clamp(120.0, 220.0);
                        return Stack(fit: StackFit.expand, children: [
                          Positioned.fill(
                              child: showingResult
                                  ? const ColoredBox(color: Color(0xFF171A19))
                                  : camera != null
                                      ? ListenableBuilder(
                                          listenable: camera,
                                          builder: (_, __) => camera
                                                  .source.ready
                                              ? camera.source.preview()
                                              : camera.stage ==
                                                          CaptureStage
                                                              .reviewing ||
                                                      camera.stage ==
                                                          CaptureStage.prepared
                                                  ? const ColoredBox(
                                                      color: Color(0xFF171A19),
                                                      child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                  color: Color(
                                                                      0xFF70D9CC))))
                                                  : Center(
                                                      child: Text(
                                                          camera.error ??
                                                              'Đang mở camera…',
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white))))
                                      : const ColoredBox(
                                          color: Color(0xFF171A19))),
                          if (showingResult)
                            Positioned(
                                top: 48,
                                left: 36,
                                right: 36,
                                height: frameHeight,
                                child: Container(
                                    key: const Key('scan-preview'),
                                    color: const Color(0xFF303735),
                                    child: Center(
                                        child: _image != null
                                            ? Image.memory(_image!,
                                                fit: BoxFit.contain,
                                                excludeFromSemantics: true)
                                            : const SizedBox.shrink()))),
                          if (showingResult)
                            Positioned(
                                top: 48,
                                left: 36,
                                right: 36,
                                height: frameHeight,
                                child: CustomPaint(
                                    key: const Key('scan-frame'),
                                    painter: _ScanCorners())),
                          if (!showingResult)
                            Center(
                                child: Container(
                                    margin: const EdgeInsets.all(36),
                                    width: double.infinity,
                                    height: 220,
                                    child:
                                        CustomPaint(painter: _ScanCorners()))),
                          if (_screen == _Screen.camera)
                            const Positioned(
                                top: 12,
                                left: 16,
                                right: 16,
                                child: Text('Đặt tên thuốc vào trong khung',
                                    key: Key('scan-hint'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                              blurRadius: 6,
                                              color: Colors.black)
                                        ]))),
                          if (_screen == _Screen.camera)
                            const Center(
                                child: SizedBox(
                                    height: _cameraFrameHeight,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 42),
                                      child: _ScanBeam(),
                                    ))),
                          if (_screen == _Screen.recognizing)
                            Positioned.fill(
                                child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _failDuringRecognition)),
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
                                                    8)))))),
                        ]);
                      })),
            if (_screen == _Screen.camera) _cameraActions(),
            if (_screen == _Screen.failure)
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                      width: double.infinity,
                      child: Column(children: [
                        if (_ocr?.result != null || _nameMissed) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56)),
                              onPressed: _manualEntry,
                              child: const Text('Tìm thuốc thủ công')),
                        ],
                        if (!_invalidated)
                          TextButton(
                              onPressed:
                                  _retryingGallery ? null : _chooseAnotherPhoto,
                              child: const Text('Chọn ảnh khác')),
                        FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56)),
                            onPressed: _retryingGallery ? null : _retake,
                            child: const Text('Chụp lại')),
                      ]))),
          ]))),
    );
  }

  Widget _cameraActions() => ListenableBuilder(
      listenable: _camera ?? _empty,
      builder: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    IconButton.filledTonal(
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF303030),
                            foregroundColor: Colors.white,
                            fixedSize: const Size(56, 56)),
                        onPressed: _camera?.busy == false
                            ? () => _capture(gallery: true)
                            : null,
                        icon: const Icon(LucideIcons.image),
                        tooltip: 'Thư viện'),
                    const SizedBox(height: 6),
                    const Text('Thư viện',
                        style: TextStyle(color: Colors.white, fontSize: 13))
                  ]),
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
                              border:
                                  Border.all(color: Colors.white, width: 3)),
                          child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle)))),
                  Column(children: [
                    IconButton.filledTonal(
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF303030),
                            foregroundColor: Colors.white,
                            fixedSize: const Size(56, 56)),
                        onPressed: _manualEntry,
                        tooltip: 'Nhập tay',
                        icon: const Icon(LucideIcons.pencil)),
                    const SizedBox(height: 6),
                    const Text('Nhập tay',
                        style: TextStyle(color: Colors.white, fontSize: 13))
                  ]),
                ]),
            const SizedBox(height: 10),
            const Text('Ảnh chỉ xử lý trên điện thoại của bạn',
                style: TextStyle(color: Colors.white70)),
            if (_camera?.permissionStatus ==
                CapturePermission.permanentlyDenied)
              TextButton(
                  onPressed:
                      _camera?.busy == true ? null : _camera?.openSettings,
                  child: const Text('Mở cài đặt')),
          ])));

  static final ChangeNotifier _empty = ChangeNotifier();

  Widget _failureBody() => Center(
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFEFDC), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.scanLine,
                        color: Color(0xFFE77D0A), size: 64)),
                const SizedBox(height: 24),
                Text(_failureTitle,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_failure ?? 'Hãy quét lại theo gợi ý bên dưới.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(LucideIcons.sun, color: Color(0xFFDF7900)),
                            SizedBox(width: 12),
                            Expanded(child: Text('Đủ ánh sáng, không bị loá'))
                          ]),
                          SizedBox(height: 16),
                          Row(children: [
                            Icon(LucideIcons.scanLine,
                                color: Color(0xFF00534D)),
                            SizedBox(width: 12),
                            Expanded(child: Text('Tên thuốc nằm trong khung'))
                          ]),
                        ])),
              ]))));

  /// [maxHeight] keeps the sheet below the photo so the box stays visible
  /// while the user compares it with the one result. Only the card scrolls: the
  /// buttons stay pinned at the bottom of the sheet (adhoc-20261120 nhận xét 2).
  Widget _resultSheet(double maxHeight) => Container(
      key: const Key('scan-result-sheet'),
      width: double.infinity,
      constraints: _screen == _Screen.result
          ? BoxConstraints(maxHeight: maxHeight)
          : null,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: _screen == _Screen.recognizing
          ? SingleChildScrollView(child: _recognizingContent())
          : Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              const SizedBox(height: 14),
              const Text('Có đúng thuốc trên vỏ hộp không?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
                              checkReminder: _checkReminder))),
              const SizedBox(height: 12),
              if (_candidate != null)
                OcrResultActions(
                    onConfirm: _confirm,
                    onNotThis: _manualEntry,
                    onRetake: _retake)
              else
                TextButton(onPressed: _retake, child: const Text('Chụp lại')),
            ]));

  /// Title + the three pinned buttons + a little of the card.
  static const double _minResultSheetHeight = 340;

  Widget _sheetHandle() => Center(
      child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFD6D8D6),
              borderRadius: BorderRadius.circular(4))));

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
              const SizedBox(height: 12),
              const Row(children: [
                ScanningMascot(size: 72),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Đang nhận diện thuốc...',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 12),
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
                          color: const Color(0xFF00534D),
                          backgroundColor: const Color(0xFFE5F3EF)))),
              const SizedBox(height: 16),
              RecognitionSteps(stage: stage),
              const SizedBox(height: 4),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F5F3),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(LucideIcons.shield,
                        size: 18, color: Color(0xFF00534D)),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('Ảnh chỉ xử lý trên máy, không gửi đi',
                            style: TextStyle(fontSize: 12)))
                  ])),
            ]);
      });
}
