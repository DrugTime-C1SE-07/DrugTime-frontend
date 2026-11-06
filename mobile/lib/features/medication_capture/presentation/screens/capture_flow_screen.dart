import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/capture_services.dart';
import '../../domain/capture_models.dart';
import '../state/capture_controller.dart';
import '../state/capture_scope.dart';
import 'camera_capture_screen.dart';
import 'capture_edit_screen.dart';
import '../../domain/ocr_models.dart';
import 'ocr_flow_screen.dart';

class CaptureFlowScreen extends StatefulWidget {
  const CaptureFlowScreen({super.key, this.services, this.initialImage});
  final CaptureServices? services;
  final Uint8List? initialImage;
  @override
  State<CaptureFlowScreen> createState() => _CaptureFlowScreenState();
}

class _CaptureFlowScreenState extends State<CaptureFlowScreen>
    with WidgetsBindingObserver {
  late final CaptureServices _services;
  late final CaptureController _controller;
  bool _finished = false;
  PreparedMedicationImage? _ocrImage;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _services = widget.services ?? CaptureScope.maybeOf(context)!;
    _controller = CaptureController(
        source: _services.newSource(),
        processor: _services.processor,
        store: _services.store,
        session: _services);
    _services.addListener(_sessionEnded);
    if (widget.initialImage case final bytes?) {
      unawaited(_controller.accept(bytes));
    } else {
      unawaited(_controller.start());
    }
  }

  void _sessionEnded() {
    if (mounted && !_finished) _finish(const CaptureResult.aborted());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_controller.background());
    }
    if (state == AppLifecycleState.resumed) unawaited(_controller.resume());
  }

  void _finish(CaptureResult result) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _use() async {
    final prepared = await _controller.prepare();
    if (prepared != null && mounted && !_finished) {
      _controller.takeLease();
      _discardPreview();
      setState(() {
        _ocrImage = prepared;
      });
    }
  }

  void _discardPreview() {
    final preview = _controller.image;
    _controller.image = null;
    if (preview != null) {
      // Image.memory uses this provider as its cache key. The OCR lease owns a
      // separate read buffer; do not retain the review image for the result UI.
      unawaited(MemoryImage(preview.bytes).evict());
    }
  }

  void _retake() {
    setState(() {
      _ocrImage = null;
    });
    unawaited(_controller.retake());
  }

  void _ocrExit(OcrMatchResult? result) => _finish(result == null
      ? const CaptureResult.aborted()
      : CaptureResult.candidates(result));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _services.removeListener(_sessionEnded);
    _discardPreview();
    final image = _ocrImage;
    if (image != null) unawaited(_services.release(image));
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _ocrImage != null
          ? OcrFlowScreen(
              key: ValueKey(_ocrImage!.id),
              image: _ocrImage!,
              services: _services,
              onRetake: _retake,
              onExit: _ocrExit)
          : _controller.stage == CaptureStage.reviewing ||
                  _controller.stage == CaptureStage.prepared
              ? CaptureEditScreen(
                  controller: _controller,
                  onUse: _use,
                  onRetake: _controller.retake)
              : CameraCaptureScreen(
                  controller: _controller,
                  onClose: () => _finish(const CaptureResult.aborted())));
}
