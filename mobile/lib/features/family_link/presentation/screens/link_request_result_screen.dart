import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../state/link_request_controller.dart';

/// Tham số mở màn hình kết quả gửi yêu cầu liên kết.
class LinkRequestResultArgs {
  const LinkRequestResultArgs({
    required this.outcome,
    this.recipientName,
    this.recipientRole,
    this.recipientContact,
    this.onCancelRequest,
    this.showCancelButton = true,
  });

  final LinkSubmitOutcome outcome;
  final String? recipientName;
  final String? recipientRole;
  final String? recipientContact;
  final VoidCallback? onCancelRequest;
  final bool showCancelButton;
}

/// Kết quả gửi yêu cầu theo dõi người thân:
/// - Đang chờ xác nhận (Figma S08-3d): Header "Đang chờ xác nhận", linh vật Dumi,
///   status badge "Đang chờ duyệt", thẻ Người nhận yêu cầu (Avatar initials, họ tên, vai trò),
///   ghi chú quyền hạn, nút Outlined đỏ "Hủy yêu cầu" và nút Filled "Về trang chủ".
/// - Đã được chấp thuận: Danh sách 4 mục dữ liệu sẽ được xem khi người thân bật chia sẻ.
class LinkRequestResultScreen extends StatelessWidget {
  const LinkRequestResultScreen({
    super.key,
    required this.outcome,
    this.recipientName,
    this.recipientRole,
    this.recipientContact,
    this.onCancelRequest,
    this.showCancelButton = true,
  });

  /// Những mục người thân xem được khi chia sẻ đang bật (theo phạm vi backend; không có
  /// hồ sơ sức khỏe — HBR-18 chưa chốt).
  static const sharedScopes = [
    (Icons.event_note_outlined, 'Lịch uống thuốc'),
    (Icons.notifications_none, 'Cảnh báo bỏ lỡ liều'),
    (Icons.medication_outlined, 'Tủ thuốc & tương tác'),
    (Icons.insights_outlined, 'Lịch sử tuân thủ'),
  ];

  final LinkSubmitOutcome outcome;
  final String? recipientName;
  final String? recipientRole;
  final String? recipientContact;
  final VoidCallback? onCancelRequest;
  final bool showCancelButton;

  String get _avatarInitials {
    final name = (recipientName ?? 'Nguyễn Thị Hoa').trim();
    if (name.isEmpty) return 'TH';
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts[parts.length - 2].characters.first.toUpperCase();
      final last = parts.last.characters.first.toUpperCase();
      return '$first$last';
    }
    return parts.first.characters.take(2).toString().toUpperCase();
  }

  void _confirmCancel(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy yêu cầu theo dõi?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy yêu cầu kết nối với người thân này? '
          'Bạn có thể gửi lại yêu cầu bất kỳ lúc nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onCancelRequest?.call();
              Navigator.of(context).pop();
            },
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (asset, title, body) = switch (outcome) {
      LinkSubmitOutcome.waiting => (
          'assets/icons/mascot-thinking.png',
          'Đang chờ xác nhận',
          'Đã gửi yêu cầu theo dõi. Người thân cần chấp thuận thì bạn mới xem được thông tin của họ. '
              'Bạn có thể xem lịch uống thuốc sau khi người thân chấp nhận yêu cầu.',
        ),
      LinkSubmitOutcome.accepted => (
          'assets/icons/mascot-happy.png',
          'Đã được chấp thuận',
          'Người thân đã đồng ý liên kết. Khi người thân bật chia sẻ, bạn sẽ xem được:',
        ),
    };

    return Scaffold(
      backgroundColor: profileFlowCanvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    // Linh vật Dumi
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.brandTint,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.cardElevation,
                      ),
                      child: Image.asset(asset, excludeFromSemantics: true),
                    ),
                    const SizedBox(height: 16),

                    // Status Badge (Đang chờ duyệt hoặc Đã liên kết)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: outcome == LinkSubmitOutcome.waiting
                            ? const Color(0xFFFEF3E2)
                            : const Color(0xFFE3F4F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: outcome == LinkSubmitOutcome.waiting
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFBBE5DD),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            outcome == LinkSubmitOutcome.waiting
                                ? Icons.hourglass_top_rounded
                                : Icons.check_circle_outline,
                            size: 14,
                            color: outcome == LinkSubmitOutcome.waiting
                                ? const Color(0xFFD97706)
                                : const Color(0xFF01554F),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              outcome == LinkSubmitOutcome.waiting
                                  ? 'Đang chờ duyệt'
                                  : 'Đã chấp thuận',
                              style: AppTextStyles.caption.copyWith(
                                color: outcome == LinkSubmitOutcome.waiting
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF01554F),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Heading & Subtext
                    Text(
                      title,
                      key: const Key('link-result-title'),
                      style: AppTextStyles.title.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF211D1D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF5B6169),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Thẻ người nhận yêu cầu (Figma S08-3d)
                    if (outcome == LinkSubmitOutcome.waiting) ...[
                      Container(
                        key: const Key('link-result-recipient-card'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE4E4E1)),
                          boxShadow: AppShadows.cardElevation,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE3F4F0),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _avatarInitials,
                                style: const TextStyle(
                                  color: Color(0xFF01554F),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipientName ?? 'Nguyễn Thị Hoa',
                                    key:
                                        const Key('link-result-recipient-name'),
                                    style: AppTextStyles.bodyStrong.copyWith(
                                      fontSize: 16,
                                      color: const Color(0xFF211D1D),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    recipientRole ??
                                        recipientContact ??
                                        'Người nhận yêu cầu',
                                    style: AppTextStyles.caption.copyWith(
                                      color: const Color(0xFF5B6169),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                size: 20,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Danh sách 4 quyền được xem khi đã chấp thuận
                    if (outcome == LinkSubmitOutcome.accepted) ...[
                      ProfileFlowCard(
                        key: const Key('link-result-scopes'),
                        child: Column(
                          children: [
                            for (final (icon, label) in sharedScopes)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(icon, color: AppColors.brand),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(label,
                                          style: AppTextStyles.body),
                                    ),
                                    const Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: AppColors.inkMuted,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Thẻ ghi chú quyền hạn (Privacy note)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2ECE9)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            outcome == LinkSubmitOutcome.waiting
                                ? Icons.schedule
                                : Icons.shield_outlined,
                            size: 20,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outcome == LinkSubmitOutcome.waiting
                                      ? 'Chưa có quyền xem dữ liệu'
                                      : 'Quyền xem phụ thuộc vào chia sẻ',
                                  style: AppTextStyles.bodyStrong.copyWith(
                                    fontSize: 14,
                                    color: const Color(0xFF211D1D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Người thân chỉ thấy lịch uống thuốc và cảnh báo — không xem được chi tiết dị ứng, bệnh nền hay hồ sơ y tế.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: const Color(0xFF5B6169),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons (Hủy yêu cầu + Về trang chủ / Xong)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (outcome == LinkSubmitOutcome.waiting &&
                      showCancelButton) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('link-result-cancel'),
                        onPressed: () => _confirmCancel(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Hủy yêu cầu'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          backgroundColor: const Color(0xFFFFF3F2),
                          side: const BorderSide(color: Color(0xFFEDCAC7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      key: const Key('link-result-done'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF01554F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          outcome == LinkSubmitOutcome.waiting
                              ? 'Về trang chủ'
                              : 'Xong',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
