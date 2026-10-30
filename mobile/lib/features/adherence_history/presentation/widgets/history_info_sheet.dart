import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/preview/app_preview_scope.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import 'history_motion.dart';

class HistoryInfoButton extends StatefulWidget {
  const HistoryInfoButton({super.key});
  @override
  State<HistoryInfoButton> createState() => _HistoryInfoButtonState();
}

class _HistoryInfoButtonState extends State<HistoryInfoButton>
    with WidgetsBindingObserver {
  final _focus = FocusNode();
  AnimationController? _sheetAnimation;
  AdherenceHistoryController? _controller;
  ModalRoute<dynamic>? _route;
  int? _revision;
  bool _open = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      final animation = _sheetAnimation;
      if (animation != null) {
        animation.duration = Duration.zero;
        animation.reverseDuration = Duration.zero;
        animation.stop();
        // Complete the current transition without replaying or moving focus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(animation, _sheetAnimation)) {
            animation.value =
                animation.status == AnimationStatus.reverse ? 0 : 1;
          }
        });
      }
    }
  }

  void _changed() {
    if (_controller?.accessRevision == _revision) return;
    final route = _route;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _controller?.deactivate();
    }
  }

  Future<void> _show() async {
    if (_open) return;
    final c = AdherenceHistoryScope.read(context);
    final revision = c.accessRevision;
    if (c.error?.removesAccess == true) return;
    _controller = c;
    _revision = revision;
    _open = true;
    c.addListener(_changed);
    final preview = AppPreviewScope.maybeOf(context);
    final reduced = !HistoryMotion.enabled(context);
    final animation = AnimationController(
        vsync: Navigator.of(context),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 250),
        reverseDuration:
            reduced ? Duration.zero : const Duration(milliseconds: 220));
    _sheetAnimation = animation;
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          transitionAnimationController: animation,
          builder: (context) {
            _route = ModalRoute.of(context);
            return AnimatedBuilder(
                animation: c,
                builder: (context, _) => c.accessRevision != revision
                    ? const SizedBox.shrink()
                    : SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Về lịch sử',
                                    style: AppTextStyles.heading),
                                const SizedBox(height: 16),
                                const Text(
                                    'Đã uống gồm cả liều uống trễ.\n\nLiều chờ chưa tính vào tỷ lệ.\n\nBỏ lỡ: chưa ghi nhận đã uống đúng hạn.\n\nNgày không có dấu: chưa có lịch sử.',
                                    style: AppTextStyles.body),
                                if (preview != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                      'Mẫu · ${HistoryFormat.day(HistoryFormat.today(preview.clock))} · 14:00 (giờ Việt Nam)',
                                      style: AppTextStyles.body),
                                ],
                                const SizedBox(height: 24),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Đóng')),
                              ]),
                        )));
          });
    } finally {
      // The pop result completes before the reverse transition. The route must
      // finish using our controller before it can be released.
      final route = _route;
      if (route != null) await route.completed;
      c.removeListener(_changed);
      _route = null;
      _controller = null;
      _open = false;
      if (identical(_sheetAnimation, animation)) {
        _sheetAnimation = null;
        animation.dispose();
      }
      if (mounted && c.accessRevision == revision) _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);
    _sheetAnimation?.dispose();
    _sheetAnimation = null;
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
      key: const Key('history-info'),
      focusNode: _focus,
      tooltip: 'Giải thích lịch sử',
      onPressed: _show,
      icon: const Icon(Icons.info_outline));
}
