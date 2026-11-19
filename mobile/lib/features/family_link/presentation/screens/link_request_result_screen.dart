import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../state/link_request_controller.dart';

/// Kết quả gửi yêu cầu: đang chờ patient chấp thuận (Figma S08-3d, đã bỏ tên, avatar và nút hủy
/// vì contract không trả thông tin hồ sơ và chưa có endpoint hủy), hoặc đã được chấp thuận.
/// Không hiện dữ liệu nào của patient.
class LinkRequestResultScreen extends StatelessWidget {
  const LinkRequestResultScreen({super.key, required this.outcome});

  final LinkSubmitOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (asset, title, body) = switch (outcome) {
      LinkSubmitOutcome.waiting => (
          'assets/icons/mascot-thinking.png',
          'Đang chờ xác nhận',
          'Đã gửi yêu cầu theo dõi. Người thân cần chấp thuận thì bạn mới xem được thông tin '
              'của họ. Bạn chưa xem được gì cho tới lúc đó.',
        ),
      LinkSubmitOutcome.accepted => (
          'assets/icons/mascot-happy.png',
          'Đã được chấp thuận',
          'Người thân đã chấp thuận yêu cầu theo dõi của bạn.',
        ),
    };
    return Scaffold(
      backgroundColor: profileFlowCanvas,
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(children: [
                  Container(
                      width: 116,
                      height: 116,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                          color: AppColors.brandTint,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.cardElevation),
                      child: Image.asset(asset, excludeFromSemantics: true)),
                  const SizedBox(height: 24),
                  Text(title,
                      key: const Key('link-result-title'),
                      style: AppTextStyles.title,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(body,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ProfileFlowCard(
                      child: Row(children: [
                    Icon(
                        outcome == LinkSubmitOutcome.waiting
                            ? Icons.schedule
                            : Icons.check_circle_outline,
                        color: AppColors.brand),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            outcome == LinkSubmitOutcome.waiting
                                ? 'Chưa có quyền xem dữ liệu'
                                : 'Quyền xem phụ thuộc vào chia sẻ và sự đồng ý của người thân.',
                            style: AppTextStyles.caption)),
                  ])),
                ]))),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: ProfileFlowButton(
                key: const Key('link-result-done'),
                label: 'Xong',
                onPressed: () => Navigator.of(context).pop())),
      ])),
    );
  }
}
