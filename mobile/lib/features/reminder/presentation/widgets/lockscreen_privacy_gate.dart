import 'package:flutter/material.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/platform/keyguard_service.dart';

import 'reminder_mascot.dart';
import 'reminder_scene.dart';

/// Widget bọc màn hình nhắc thuốc [DoseReminderScreen] trên màn hình khóa.
///
/// Tuân thủ nguyên tắc quyền riêng tư NT-02:
/// - Khi thiết bị đang khóa (`isKeyguardLocked == true`):
///   Chỉ hiển thị thông báo chung "Đến giờ uống thuốc", tuyệt đối không hiển thị
///   tên thuốc, danh sách thuốc hay liều lượng.
/// - Android yêu cầu xác thực trước khi thực hiện các tác vụ nhạy cảm trên màn hình khóa.
///   Do đó, người dùng phải mở khóa máy (bấm "Mở khóa thiết bị") trước khi có thể
///   tương tác với thông tin và xác nhận cữ thuốc.
/// - Khi thiết bị đã mở khóa: Hiển thị toàn bộ [child].
///
/// Giao diện khi khóa dùng chung cảnh trời theo giờ và pet với màn nhắc ([ReminderScene]).
class LockscreenPrivacyGate extends StatefulWidget {
  const LockscreenPrivacyGate({
    super.key,
    required this.child,
    this.platform,
    this.clock,
  });

  final Widget child;
  final KeyguardPlatform? platform;

  /// Đồng hồ cho giờ hiển thị và cảnh trời; mặc định giờ thật.
  final DateTime Function()? clock;

  @override
  State<LockscreenPrivacyGate> createState() => _LockscreenPrivacyGateState();
}

class _LockscreenPrivacyGateState extends State<LockscreenPrivacyGate>
    with WidgetsBindingObserver {
  late final KeyguardPlatform _platform;
  bool _isChecking = true;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _platform = widget.platform ?? const DefaultKeyguardPlatform();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  Future<void> _checkLockStatus() async {
    final locked = await _platform.isKeyguardLocked();
    if (mounted) {
      setState(() {
        _isLocked = locked;
        _isChecking = false;
      });
    }
  }

  Future<void> _handleUnlockRequest() async {
    final success = await _platform.requestDismissKeyguard();
    if (success) {
      await _checkLockStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: AppColors.brandStrong,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!_isLocked) {
      return widget.child;
    }

    final now = (widget.clock ?? DateTime.now)().toUtc();
    final vn = now.add(const Duration(hours: 7));
    final timeLabel = '${vn.hour.toString().padLeft(2, '0')}:'
        '${vn.minute.toString().padLeft(2, '0')}';
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final dateLabel = '${weekdays[vn.weekday - 1]}, '
        '${vn.day.toString().padLeft(2, '0')}/'
        '${vn.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.brandStrong,
      body: ReminderScene(
        clock: widget.clock,
        builder: (context, ink, groundKey) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _headerPill(),
                        const SizedBox(height: AppSpacing.lg),
                        FittedBox(
                          child: Text(
                            timeLabel,
                            style: TextStyle(
                              color: ink.strong,
                              fontSize: 64,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          dateLabel,
                          style: AppTextStyles.body.copyWith(color: ink.soft),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        KeyedSubtree(
                          key: groundKey,
                          child: ReminderMascot(
                            key: const Key('lockscreen-mascot'),
                            scheduledAt: now,
                            now: now,
                            confirmed: false,
                            hasError: false,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Mở khóa máy để xem và xác nhận thuốc nhé!',
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Color(0x99000000), blurRadius: 6),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _maskedCard(),
                      ],
                    ),
                  ),
                ),
                _actionPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerPill() => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1D746E),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 18, color: Colors.white),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'DrugTime · Đến giờ uống thuốc',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

  /// Thẻ che thông tin thuốc (NT-02): không có tên, danh sách hay liều lượng.
  Widget _maskedCard() => InkWell(
        onTap: _handleUnlockRequest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đến giờ uống thuốc',
                        style: AppTextStyles.bodyStrong,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Thiết bị đang khóa. Mở khóa để xem chi tiết.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.lock_outline, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      );

  /// Nút giống màn nhắc; mọi nút đều yêu cầu mở khóa trước.
  Widget _actionPanel() => Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.brandStrong.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: AppSizes.primaryButton,
              child: FilledButton.icon(
                key: const Key('lockscreen_unlock_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.brand,
                ),
                onPressed: _handleUnlockRequest,
                icon: const Icon(Icons.check),
                label: const Text('Đã uống'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: AppSizes.tapTarget,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onBrand,
                  side: const BorderSide(color: Color(0xFF7AB0AC)),
                ),
                onPressed: _handleUnlockRequest,
                icon: const Icon(Icons.access_time, size: 20),
                label: const Text('Nhắc lại sau 10 phút'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: AppSizes.tapTarget,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD9E7E6),
                ),
                onPressed: _handleUnlockRequest,
                child: const Text('Bỏ qua liều này'),
              ),
            ),
          ],
        ),
      );
}
