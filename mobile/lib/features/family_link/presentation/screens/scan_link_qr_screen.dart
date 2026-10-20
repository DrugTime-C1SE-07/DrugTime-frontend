import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../data/sources/camera_permission.dart';
import '../../domain/entities/link_code.dart';
import '../state/family_link_scope.dart';
import '../widgets/link_request_messages.dart';
import 'enter_link_code_screen.dart';

/// Dựng phần camera; gọi [onDetect] với nội dung thô của mỗi mã QR đọc được.
typedef QrScannerBuilder = Widget Function(BuildContext context, ValueChanged<String> onDetect);

/// Người thân quét mã QR của patient (Figma S08-3c). Chỉ nhận `drugtime://link?code=`; mã hợp lệ
/// đầu tiên được chuyển sang màn nhập mã để gửi, mọi lần đọc sau bị bỏ qua.
class ScanLinkQrScreen extends StatefulWidget {
  const ScanLinkQrScreen({super.key, this.scannerBuilder});

  /// Test truyền scanner giả; `null` thì dùng camera thật (`mobile_scanner`).
  final QrScannerBuilder? scannerBuilder;

  @override
  State<ScanLinkQrScreen> createState() => _ScanLinkQrScreenState();
}

class _ScanLinkQrScreenState extends State<ScanLinkQrScreen> with WidgetsBindingObserver {
  late final CameraPermission _permission = FamilyLinkScope.read(context).cameraPermission;
  MobileScannerController? _camera;
  CameraPermissionStatus? _status;
  // Hộp thoại quyền làm app inactive rồi resumed; không gửi yêu cầu thứ hai khi yêu cầu trước
  // chưa xong (permission_handler báo lỗi "already running").
  bool _requesting = false;
  bool _openedSettings = false;
  bool _handled = false;
  bool _showInvalid = false;
  Timer? _hideInvalid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.scannerBuilder == null) {
      _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_requestPermission()));
  }

  // Chỉ kiểm lại quyền khi quay về từ trang Cài đặt mà màn này đã mở.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedSettings) {
      _openedSettings = false;
      unawaited(_requestPermission());
    }
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    _requesting = true;
    CameraPermissionStatus status;
    try {
      status = await _permission.request();
    } on Exception {
      // Không xin được quyền (lỗi nền tảng): coi như bị từ chối để người dùng còn lối Nhập mã.
      status = CameraPermissionStatus.denied;
    } finally {
      _requesting = false;
    }
    if (mounted) setState(() => _status = status);
  }

  void _openSettings() {
    _openedSettings = true;
    unawaited(_permission.openSettings());
  }

  void _onDetect(String raw) {
    if (_handled || !mounted) return;
    final code = linkCodeFromQrPayload(raw);
    if (code == null) {
      _hideInvalid?.cancel();
      setState(() => _showInvalid = true);
      _hideInvalid = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showInvalid = false);
      });
      return;
    }
    _handled = true;
    unawaited(_camera?.stop());
    unawaited(Navigator.of(context).pushReplacementNamed(
      AppRoutes.familyEnterCode,
      arguments: EnterLinkCodeArgs(initialCode: code, autoSubmit: true),
    ));
  }

  void _openEnterCode() {
    _handled = true;
    unawaited(Navigator.of(context).pushReplacementNamed(AppRoutes.familyEnterCode));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideInvalid?.cancel();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_status) {
        null => const Center(child: CircularProgressIndicator()),
        CameraPermissionStatus.granted => _buildScanner(context),
        final status => _PermissionDenied(
            permanently: status == CameraPermissionStatus.permanentlyDenied,
            onEnterCode: _openEnterCode,
            onRetry: () => unawaited(_requestPermission()),
            onOpenSettings: _openSettings,
          ),
      },
    );
  }

  Widget _buildScanner(BuildContext context) {
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.scannerBuilder?.call(context, _onDetect) ??
            MobileScanner(
              controller: camera,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue case final raw?) _onDetect(raw);
                }
              },
              errorBuilder: (context, _) => const _CameraError(),
            ),
        const _Viewfinder(),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('scan-close'),
                      tooltip: 'Đóng',
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (camera != null) _TorchButton(camera: camera),
                  ],
                ),
              ),
              const Spacer(),
              if (_showInvalid)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Text(
                    invalidQrMessage,
                    key: Key('scan-invalid-qr'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.cautionBg, fontWeight: FontWeight.w600),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      'Đưa mã QR của người thân vào khung hình',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Nhờ người thân mở mục Người thân → Mã liên kết của tôi trong app DrugTime',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('scan-enter-code'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _openEnterCode,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Nhập mã'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.camera});

  final MobileScannerController camera;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: camera,
      builder: (context, state, _) {
        if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
        final on = state.torchState == TorchState.on;
        return IconButton(
          key: const Key('scan-torch'),
          tooltip: on ? 'Tắt đèn' : 'Bật đèn',
          color: Colors.white,
          icon: Icon(on ? Icons.flash_on : Icons.flash_off),
          onPressed: () => unawaited(camera.toggleTorch()),
        );
      },
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Không mở được camera. Bạn có thể nhập mã thay thế.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({
    required this.permanently,
    required this.onEnterCode,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanently;
  final VoidCallback onEnterCode;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 56, color: AppColors.inkMuted),
                const SizedBox(height: AppSpacing.lg),
                const Text('Chưa có quyền dùng camera', style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  permanently
                      ? 'Bạn đã tắt quyền camera cho DrugTime. Hãy bật lại trong Cài đặt, '
                          'hoặc nhập mã thay cho việc quét.'
                      : 'DrugTime cần camera để quét mã QR của người thân. Bạn cũng có thể nhập mã.',
                  key: const Key('camera-permission-message'),
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.primaryButton,
                  child: FilledButton(
                    key: const Key('camera-denied-enter-code'),
                    onPressed: onEnterCode,
                    child: const Text('Nhập mã'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (permanently)
                  OutlinedButton(
                    key: const Key('camera-open-settings'),
                    onPressed: onOpenSettings,
                    child: const Text('Mở Cài đặt'),
                  )
                else
                  OutlinedButton(
                    key: const Key('camera-retry'),
                    onPressed: onRetry,
                    child: const Text('Cho phép camera'),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
