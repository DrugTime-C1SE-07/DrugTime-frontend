import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/capture_models.dart';
import '../state/capture_controller.dart';

/// Full-image review; editing tools are intentionally absent.
class CaptureEditScreen extends StatelessWidget {
  const CaptureEditScreen({
    super.key,
    required this.controller,
    required this.onUse,
    required this.onRetake,
  });
  final CaptureController controller;
  final VoidCallback onUse, onRetake;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text('Xem lại ảnh',
                      style: AppTextStyles.heading
                          .copyWith(color: AppColors.onCamera)),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, size) {
                    final wide = size.maxWidth > 600 &&
                        size.maxWidth > size.maxHeight * 1.25;
                    final image = controller.image;
                    final photo = Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: image != null
                            ? Image.memory(
                                image.bytes,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                semanticLabel: 'Ảnh đã chụp hoặc chọn',
                              )
                            : controller.busy
                                ? const CircularProgressIndicator(
                                    color: AppColors.cameraAccent)
                                : const Icon(Icons.broken_image_outlined,
                                    size: 48, color: AppColors.cameraMuted),
                      ),
                    );
                    final actions = _ReviewActions(
                      controller: controller,
                      onUse: onUse,
                      onRetake: onRetake,
                      sidebar: wide,
                    );
                    return wide
                        ? Row(children: [
                            Expanded(child: photo),
                            SizedBox(width: 300, child: actions),
                          ])
                        : Column(children: [
                            Expanded(child: photo),
                            actions,
                          ]);
                  }),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.controller,
    required this.onUse,
    required this.onRetake,
    required this.sidebar,
  });
  final CaptureController controller;
  final VoidCallback onUse, onRetake;
  final bool sidebar;

  String _warning(CaptureWarning value) => switch (value) {
        CaptureWarning.dark => 'Ảnh quá tối. Hãy chụp lại ở nơi đủ sáng.',
        CaptureWarning.blurred => 'Ảnh bị mờ. Hãy giữ máy chắc và chụp lại.',
        CaptureWarning.bright => 'Có vùng quá sáng. Thử đổi góc chụp.',
        CaptureWarning.lowTexture => 'Kiểm tra ảnh trước khi sử dụng.',
      };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final image = c.image;
    final warning = image != null && image.warnings.isNotEmpty;
    final message = c.error ??
        (c.busy
            ? 'Đang chuẩn bị ảnh…'
            : image == null
                ? 'Không mở được ảnh. Hãy chụp lại.'
                : warning
                    ? _warning(c.blockingWarning ?? image.warnings.first)
                    : 'Ảnh đã sẵn sàng');
    final status = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Semantics(
        liveRegion: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(
            child: Icon(
              c.error != null || warning
                  ? Icons.info_outline
                  : Icons.check_circle_outline,
              color: AppColors.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppTextStyles.body)),
        ]),
      ),
    );
    final buttons = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(
          onPressed: c.canUseImage ? onUse : null,
          child: const Text('Dùng ảnh này'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetake, child: const Text('Chụp lại')),
      ]),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: sidebar
            ? const BorderRadius.horizontal(left: Radius.circular(24))
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: sidebar
          ? Column(children: [
              Expanded(child: SingleChildScrollView(child: status)),
              buttons,
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [status, buttons]),
    );
  }
}
