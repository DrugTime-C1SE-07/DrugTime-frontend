import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/capture_models.dart';
import '../state/capture_controller.dart';
import '../widgets/capture_controls.dart';

/// S07a, source frame 51:5296. Opened from the main app's medication form.
class CameraCaptureScreen extends StatelessWidget {
  const CameraCaptureScreen({
    super.key,
    required this.controller,
    required this.onClose,
  });
  final CaptureController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.cameraCanvas,
          body: SafeArea(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    CaptureIconButton(
                      label: 'Đóng camera',
                      icon: Icons.close_rounded,
                      onPressed: onClose,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quét vỏ thuốc',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.onCamera,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CaptureIconButton(
                      label: 'Hướng dẫn chụp',
                      icon: Icons.help_outline_rounded,
                      onPressed: () => showCaptureHelp(context),
                    ),
                  ]),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 600 &&
                        constraints.maxWidth > constraints.maxHeight * 1.25;
                    final viewport = _CaptureViewport(controller: controller);
                    final controls = _CaptureFooter(
                      controller: controller,
                      sidebar: wide,
                    );
                    return wide
                        ? Row(children: [
                            Expanded(child: viewport),
                            SizedBox(width: 216, child: controls),
                          ])
                        : Column(children: [
                            Expanded(child: viewport),
                            controls,
                          ]);
                  }),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _CaptureViewport extends StatelessWidget {
  const _CaptureViewport({required this.controller});
  final CaptureController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ready =
        c.permissionStatus == CapturePermission.granted && c.source.ready;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(children: [
        if (ready) Positioned.fill(child: c.source.preview()),
        Column(children: [
          Expanded(
            child: ready
                ? const CaptureViewfinder()
                : _CameraStatus(controller: c),
          ),
          if (ready)
            Container(
              width: double.infinity,
              color: AppColors.cameraScrim,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Semantics(
                liveRegion: c.error != null,
                child: Text(
                  c.error ?? 'Đặt thuốc vào khung',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onCamera,
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _CameraStatus extends StatelessWidget {
  const _CameraStatus({required this.controller});
  final CaptureController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final permanent = c.permissionStatus == CapturePermission.permanentlyDenied;
    final denied = c.permissionStatus == CapturePermission.denied || permanent;
    return Column(children: [
      Expanded(
          child: LayoutBuilder(
        builder: (context, size) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.maxHeight),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (c.busy) ...[
                      const CircularProgressIndicator(
                        color: AppColors.cameraAccent,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Đang mở camera…',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.cameraMuted,
                        ),
                      ),
                    ] else ...[
                      if (size.maxHeight >= 320) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppColors.cameraSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            denied ? Icons.camera_alt_outlined : Icons.refresh,
                            size: 36,
                            color: AppColors.cameraAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        denied ? 'Bật camera' : 'Chưa mở được camera',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading.copyWith(
                          color: AppColors.onCamera,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          c.error ??
                              (permanent
                                  ? 'Bật quyền Camera cho DrugTime trong Cài đặt.'
                                  : 'Cho phép camera để chụp ảnh thuốc.'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.cameraMuted,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      )),
      if (!c.busy)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cameraAccent,
              foregroundColor: AppColors.onCameraAccent,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
            onPressed: permanent
                ? c.openSettings
                : () => c.requestPermission(request: denied),
            icon: Icon(permanent
                ? Icons.settings_outlined
                : Icons.camera_alt_outlined),
            label: Text(permanent
                ? 'Mở cài đặt'
                : denied
                    ? 'Cho phép camera'
                    : 'Thử lại'),
          ),
        ),
    ]);
  }
}

class _CaptureFooter extends StatelessWidget {
  const _CaptureFooter({
    required this.controller,
    required this.sidebar,
  });
  final CaptureController controller;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final gallery = _CaptureAction(
      label: 'Thư viện',
      tooltip: 'Chọn ảnh từ thư viện',
      icon: Icons.photo_library_outlined,
      onPressed: c.busy ? null : c.pickPhoto,
      showLabel: !sidebar,
    );
    final flash = _CaptureAction(
      label: 'Đèn',
      tooltip: c.source.flashOn ? 'Tắt đèn' : 'Bật đèn',
      icon: c.source.flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
      active: c.source.flashOn,
      onPressed: !c.busy && c.source.flashAvailable ? c.toggleFlash : null,
      showLabel: !sidebar,
    );
    final shutter = SizedBox.square(
      dimension: 84,
      child: IconButton(
        tooltip: 'Chụp ảnh',
        onPressed: !c.busy && c.source.ready ? c.takePhoto : null,
        padding: EdgeInsets.zero,
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: c.source.ready
                  ? AppColors.cameraAccent
                  : AppColors.cameraOutline,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.source.ready
                  ? AppColors.cameraAccent
                  : AppColors.cameraControl,
            ),
            child: Center(
              child: c.busy
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.source.ready
                            ? AppColors.onCameraAccent
                            : AppColors.cameraAccent,
                      ),
                    )
                  : Icon(
                      Icons.camera_alt_outlined,
                      size: 28,
                      color: c.source.ready
                          ? AppColors.onCameraAccent
                          : AppColors.inkDisabled,
                    ),
            ),
          ),
        ),
      ),
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (sidebar) ...[
          shutter,
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: gallery),
            const SizedBox(width: 8),
            Expanded(child: flash),
          ]),
        ] else
          Row(children: [
            Expanded(child: gallery),
            const SizedBox(width: 20),
            shutter,
            const SizedBox(width: 20),
            Expanded(child: flash),
          ]),
      ]),
    );
    return sidebar ? SingleChildScrollView(child: body) : body;
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.showLabel = true,
  });
  final String label, tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CaptureIconButton(
            label: tooltip,
            icon: icon,
            onPressed: onPressed,
            active: active,
          ),
          if (showLabel) ...[
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: onPressed == null
                      ? AppColors.inkDisabled
                      : AppColors.cameraMuted,
                ),
              ),
            ),
          ],
        ],
      );
}
