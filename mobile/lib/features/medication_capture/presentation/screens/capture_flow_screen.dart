import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/capture_services.dart';
import '../../domain/capture_models.dart';
import '../state/capture_controller.dart';
import '../state/capture_scope.dart';
import 'camera_capture_screen.dart';
import 'capture_edit_screen.dart';

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
      _finish(CaptureResult.prepared(prepared));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _services.removeListener(_sessionEnded);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _controller.stage == CaptureStage.reviewing ||
              _controller.stage == CaptureStage.prepared
          ? CaptureEditScreen(
              controller: _controller,
              onUse: _use,
              onRetake: _controller.retake)
          : CameraCaptureScreen(
              controller: _controller,
              onClose: () => _finish(const CaptureResult.aborted())));
}
