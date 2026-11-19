import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../state/link_request_controller.dart';

/// Kết quả gửi yêu cầu: đang chờ patient chấp thuận (Figma S08-3d, đã bỏ tên, avatar và nút hủy
/// vì contract không trả thông tin hồ sơ và chưa có endpoint hủy), hoặc đã được chấp thuận.
/// Không hiện dữ liệu nào của patient.
class LinkRequestResultScreen extends StatelessWidget {
  const LinkRequestResultScreen({super.key, required this.outcome});

  /// Những mục người thân xem được khi chia sẻ đang bật (theo phạm vi backend; không có
  /// hồ sơ sức khỏe — HBR-18 chưa chốt).
  static const sharedScopes = [
    (Icons.event_note_outlined, 'Lịch uống thuốc'),
    (Icons.notifications_none, 'Cảnh báo bỏ lỡ liều'),
    (Icons.medication_outlined, 'Tủ thuốc & tương tác'),
    (Icons.insights_outlined, 'Lịch sử tuân thủ'),
  ];

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
      // Contract không trả hồ sơ người được theo dõi (QD-34) nên gọi chung là "Người thân".
      // Duyệt liên kết không tự bật chia sẻ: dữ liệu chỉ xem được sau khi người thân bật.
      LinkSubmitOutcome.accepted => (
          'assets/icons/mascot-happy.png',
          'Đã được chấp thuận',
          'Người thân đã đồng ý liên kết. Khi người thân bật chia sẻ, bạn sẽ xem được:',
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
                  if (outcome == LinkSubmitOutcome.accepted) ...[
                    const SizedBox(height: 16),
                    ProfileFlowCard(
                        key: const Key('link-result-scopes'),
                        child: Column(children: [
                          for (final (icon, label) in sharedScopes)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                Icon(icon, color: AppColors.brand),
                                const SizedBox(width: 12),
                                Expanded(
                                    child:
                                        Text(label, style: AppTextStyles.body)),
                                const Icon(Icons.visibility_outlined,
                                    size: 18, color: AppColors.inkMuted),
                              ]),
                            ),
                        ])),
                  ],
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
