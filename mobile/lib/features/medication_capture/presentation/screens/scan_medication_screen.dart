import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/preview/app_preview_scope.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../../../medication/domain/entities/dose_unit.dart';
import '../../../medication/domain/entities/medication.dart';
import '../../../medication/presentation/screens/add_medication_screen.dart';
import '../../../medication/presentation/widgets/drug_catalog_sheet.dart';
import '../../data/capture_services.dart';
import '../../domain/ocr_models.dart';
import '../state/capture_controller.dart';
import '../state/capture_scope.dart';
import '../state/ocr_controller.dart';

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

class _PreviewPackage extends StatelessWidget {
  const _PreviewPackage({this.highlight = false});
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
      width: 250,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFFAF9F5),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ColoredBox(
                color: Color(0xFFE88110),
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      Expanded(
                          child: Text('Thuốc giảm đau – hạ sốt',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)))
                    ]))),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DecoratedBox(
                    decoration: _highlightDecoration(),
                    child: const FittedBox(
                        child: Text('PARACETAMOL',
                            style: TextStyle(
                                color: Color(0xFF233D59),
                                fontSize: 26,
                                fontWeight: FontWeight.w900))))),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DecoratedBox(
                    decoration: _highlightDecoration(),
                    child: const Text('500 mg',
                        style: TextStyle(
                            color: Color(0xFFE88110),
                            fontWeight: FontWeight.bold)))),
            const SizedBox(height: 8),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Hộp 10 vỉ × 10 viên nén',
                    style: TextStyle(color: Colors.grey))),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Lô SX: 0425  ·  HD: 04/2028',
                    style: TextStyle(color: Colors.grey))),
          ]));

  BoxDecoration _highlightDecoration() => BoxDecoration(
        color: highlight ? const Color(0xFFE1F4EE) : Colors.transparent,
        border: highlight ? Border.all(color: const Color(0xFF76DACC)) : null,
        borderRadius: BorderRadius.circular(6),
      );
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
  Timer? _timer;
  bool? _preview;
  bool _busy = false;
  int _generation = 0;
  _Screen _screen = _Screen.camera;
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preview != null) return;
    _route = ModalRoute.of(context);
    _preview = AppPreviewScope.maybeOf(context) != null;
    if (!_preview!) {
      _consent =
          context.getInheritedWidgetOfExactType<ConsentScope>()?.notifier;
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
    _timer?.cancel();
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
    if (_preview == true) return;
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
    final generation = ++_generation;
    if (_preview == true) {
      setState(() {
        _screen = _Screen.recognizing;
        _failure = null;
      });
      _timer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted || generation != _generation) return;
        setState(() {
          _candidate = const OcrCandidate(
              id: 1,
              name: 'Paracetamol 500mg',
              activeIngredient: 'Paracetamol',
              strengthText: '500 mg',
              dosageForm: 'Viên nén',
              hasActiveIngredients: true,
              score: 0.96);
          _screen = _Screen.result;
          _busy = false;
        });
      });
      return;
    }
    final camera = _camera!;
    if (gallery) {
      await camera.pickPhoto();
    } else {
      await camera.takePhoto();
    }
    if (!mounted || generation != _generation) return;
    if (!camera.canUseImage) {
      _busy = false;
      setState(() {
        _failure = camera.error ??
            (camera.image == null
                ? 'Không chụp được ảnh. Hãy thử lại.'
                : 'Ảnh chưa đủ rõ. Hãy quét lại.');
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
    if (result?.status == OcrMatchStatus.matched && result!.items.isNotEmpty) {
      setState(() {
        _candidate = result.items.first;
        _screen = _Screen.result;
        _busy = false;
      });
    } else {
      setState(() {
        _failure = _ocr?.failure?.message ??
            'Chưa đọc được hoặc chưa tìm thấy thuốc phù hợp.';
        _screen = _Screen.failure;
        _busy = false;
      });
    }
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
    _timer?.cancel();
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
    _timer?.cancel();
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

  Future<void> _exit() async {
    _generation++;
    _timer?.cancel();
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
    final result = await Navigator.of(context).push<Medication>(
        MaterialPageRoute(
            builder: (_) => AddMedicationScreen(scannedDrug: drug)));
    if (mounted && result != null) {
      Navigator.of(context).pop(result);
    } else if (mounted) {
      await _retake();
    }
  }

  Future<void> _manualEntry() async {
    final drug = await showDrugCatalogSheet(context);
    if (!mounted || drug == null) return;
    final result = await Navigator.of(context).push<Medication>(
      MaterialPageRoute(builder: (_) => AddMedicationScreen(scannedDrug: drug)),
    );
    if (mounted && result != null) Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _timer?.cancel();
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
                                              : Center(
                                                  child: Text(
                                                      camera.error ??
                                                          'Đang mở camera…',
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white))))
                                      : const ColoredBox(
                                          color: Color(0xFF171A19),
                                          child: Center(
                                              child: _PreviewPackage()))),
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
                                            : _preview == true
                                                ? const FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: _PreviewPackage(
                                                        highlight: true))
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
                            Center(
                                child: SizedBox(
                                    height: 220,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 42),
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: -1, end: 1),
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                                    context)
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 1400),
                                        builder: (context, value, child) =>
                                            Align(
                                          alignment: Alignment(0, value),
                                          child: child,
                                        ),
                                        child: Container(
                                            height: 2,
                                            color: const Color(0xFF76DACC)),
                                      ),
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
                                    child: _resultSheet())),
                        ]);
                      })),
            if (_screen == _Screen.camera) _cameraActions(),
            if (_screen == _Screen.failure)
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _retake, child: const Text('Quét lại')))),
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
                        onPressed: _preview == true || _camera?.busy == false
                            ? () => _capture(gallery: true)
                            : null,
                        icon: const Icon(LucideIcons.image),
                        tooltip: 'Thư viện'),
                    const SizedBox(height: 6),
                    const Text('Thư viện',
                        style: TextStyle(color: Colors.white, fontSize: 13))
                  ]),
                  IconButton(
                      onPressed: _preview == true ||
                              (_camera?.source.ready == true &&
                                  _camera?.busy == false)
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
            if (_preview != true && _camera?.source.ready == false)
              TextButton(
                  onPressed: _camera?.requestPermission,
                  child: const Text('Cho phép camera')),
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
                const Text('Chưa đọc được vỏ hộp',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  Widget _resultSheet() => Container(
      key: const Key('scan-result-sheet'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: _screen == _Screen.recognizing
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: const Color(0xFFD6D8D6),
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  const Text('Đang nhận diện thuốc...',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                          value: 0.6,
                          minHeight: 7,
                          color: Color(0xFF00534D),
                          backgroundColor: Color(0xFFE5F3EF))),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                      listenable: _ocr ?? _empty,
                      builder: (_, __) {
                        final matching = _ocr?.stage == OcrStage.matching;
                        return Column(children: [
                          _recognitionStep(
                              LucideIcons.check,
                              'Đã chụp ảnh vỏ thuốc',
                              const Color(0xFF16A34A),
                              Colors.white),
                          _recognitionStep(
                              matching
                                  ? LucideIcons.check
                                  : LucideIcons.loaderCircle,
                              matching
                                  ? 'Đã đọc chữ trên vỏ'
                                  : 'Đang đọc chữ trên vỏ',
                              const Color(0xFFE2F1ED),
                              const Color(0xFF00534D)),
                          _recognitionStep(
                              matching
                                  ? LucideIcons.loaderCircle
                                  : LucideIcons.circle,
                              matching
                                  ? 'Đang đối chiếu danh mục thuốc'
                                  : 'Đối chiếu danh mục thuốc',
                              const Color(0xFFF0F1EF),
                              matching ? const Color(0xFF00534D) : Colors.grey),
                        ]);
                      }),
                  const SizedBox(height: 12),
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
                ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD6D8D6),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 14),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE6F5EC),
                      borderRadius: BorderRadius.circular(30)),
                  child: const Text(
                      '✓  Đã nhận diện',
                      style: TextStyle(
                          color: Color(0xFF138349),
                          fontWeight: FontWeight.bold))),
              const SizedBox(height: 14),
              Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFE4E6E4)),
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                      leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFEEDC),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(LucideIcons.pill,
                              color: Color(0xFF1B4168))),
                      title: Text(_candidate?.name ?? ''),
                      subtitle: Text([
                        _candidate?.activeIngredient,
                        _candidate?.dosageForm
                      ]
                          .whereType<String>()
                          .where((v) => v.isNotEmpty)
                          .join(' · ')))),
              const SizedBox(height: 12),
              const Text('Có đúng thuốc trên vỏ hộp không?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: _retake, child: const Text('Quét lại'))),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton(
                        onPressed: _confirm,
                        child: const Text('Đúng thuốc này')))
              ]),
            ]));

  Widget _recognitionStep(
          IconData icon, String label, Color background, Color foreground) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: background, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: foreground)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: foreground == Colors.grey
                            ? Colors.grey
                            : const Color(0xFF202221),
                        fontWeight: foreground == const Color(0xFF00534D)
                            ? FontWeight.bold
                            : FontWeight.normal))),
          ]));
}
