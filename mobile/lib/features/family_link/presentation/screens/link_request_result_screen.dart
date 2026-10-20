import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../state/link_request_controller.dart';

/// Kết quả gửi yêu cầu: đang chờ patient chấp thuận (Figma S08-3d, đã bỏ tên, avatar và nút hủy
/// vì contract không trả thông tin hồ sơ và chưa có endpoint hủy), hoặc đã được chấp thuận.
/// Không hiện dữ liệu nào của patient.
class LinkRequestResultScreen extends StatelessWidget {
  const LinkRequestResultScreen({super.key, required this.outcome});

  final LinkSubmitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (outcome) {
      LinkSubmitOutcome.waiting => (
          Icons.hourglass_top_rounded,
          'Đang chờ xác nhận',
          'Đã gửi yêu cầu theo dõi. Người thân cần chấp thuận thì bạn mới xem được thông tin '
              'của họ. Bạn chưa xem được gì cho tới lúc đó.',
        ),
      LinkSubmitOutcome.accepted => (
          Icons.verified_outlined,
          'Đã được chấp thuận',
          'Người thân đã chấp thuận yêu cầu theo dõi của bạn.',
        ),
    };
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Theo dõi người thân')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: AppColors.brand),
                const SizedBox(height: AppSpacing.lg),
                Text(title, key: const Key('link-result-title'), style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.sm),
                Text(body, style: AppTextStyles.body, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.primaryButton,
                  child: FilledButton(
                    key: const Key('link-result-done'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
