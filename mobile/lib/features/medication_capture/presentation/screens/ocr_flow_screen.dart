import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/capture_services.dart';
import '../../domain/capture_models.dart';
import '../../domain/ocr_models.dart';
import '../state/ocr_controller.dart';
import 'capture_analyzing_screen.dart';
import 'ocr_candidates_screen.dart';

class OcrFlowScreen extends StatefulWidget {
  const OcrFlowScreen(
      {super.key,
      required this.image,
      required this.services,
      required this.onRetake,
      required this.onExit});
  final PreparedMedicationImage image;
  final CaptureServices services;
  final VoidCallback onRetake;
  final ValueChanged<OcrMatchResult?> onExit;
  @override
  State<OcrFlowScreen> createState() => _OcrFlowScreenState();
}

class _OcrFlowScreenState extends State<OcrFlowScreen>
    with WidgetsBindingObserver {
  late final OcrController _controller;
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = OcrController(image: widget.image, services: widget.services);
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_leave());
    }
  }

  Future<void> _leave({bool retake = false, bool result = false}) async {
    if (_leaving) return;
    _leaving = true;
    final matches = result ? _controller.result : null;
    final clean = await _controller.close();
    if (!mounted) return;
    _leaving = false;
    if (!clean) {
      setState(() {});
      return;
    }
    if (retake) {
      widget.onRetake();
    } else {
      widget.onExit(matches);
    }
  }

  Future<void> _retryCleanup() async {
    if (_leaving) return;
    _leaving = true;
    final clean = await widget.services.retryCleanup();
    if (!mounted) return;
    _leaving = false;
    if (clean) {
      widget.onExit(null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final result = _controller.result, failure = _controller.failure;
            if (result != null) {
              return OcrCandidatesScreen(
                  result: result,
                  onRetake: () => unawaited(_leave(retake: true)),
                  onExit: () => unawaited(_leave(result: true)));
            }
            if (failure != null) {
              return Scaffold(
                  appBar: AppBar(
                      title: const Text('Nhận diện bao bì'),
                      leading: IconButton(
                          tooltip: 'Quay về form',
                          onPressed: () => unawaited(_leave()),
                          icon: const Icon(Icons.arrow_back))),
                  body: SafeArea(
                      child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                        Semantics(
                            liveRegion: true, child: Text(failure.message)),
                        const SizedBox(height: 24),
                        if (failure.kind == OcrFailureKind.cleanup)
                          FilledButton(
                              onPressed: () => unawaited(_retryCleanup()),
                              child: const Text('Thử dọn lại'))
                        else ...[
                          if (failure.canRetry)
                            FilledButton(
                                onPressed: _controller.busy
                                    ? null
                                    : () => unawaited(_controller.start()),
                                child: const Text('Thử lại')),
                          OutlinedButton(
                              onPressed: () => unawaited(_leave(retake: true)),
                              child: const Text('Chụp lại')),
                          TextButton(
                              onPressed: () => unawaited(_leave()),
                              child: const Text('Quay về form')),
                        ],
                      ])));
            }
            if (_controller.stage == OcrStage.closed) {
              return const Scaffold(
                  body: SafeArea(child: Center(child: Text('Đang dọn ảnh…'))));
            }
            return CaptureAnalyzingScreen(
                step: switch (_controller.stage) {
                  OcrStage.recognizing => 1,
                  OcrStage.matching => 2,
                  _ => 0
                },
                onCancel: () => unawaited(_leave()));
          }));
}
