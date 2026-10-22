import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/presentation/widgets/consent_texts.dart';
import '../../domain/entities/incoming_link_request.dart';
import 'caregiver_messages.dart';

/// Bước xác nhận đồng ý chia sẻ khi chấp thuận một yêu cầu theo dõi (PB16, backlog 3.17).
///
/// Văn bản là mô tả mục đích `family_sharing` phiên bản `consentDocumentVersion`, đúng phiên bản
/// app gửi kèm khi chấp thuận. Trả `true` khi người dùng tick đồng ý và bấm xác nhận.
Future<bool> showApproveLinkSheet(BuildContext context, IncomingLinkRequest request) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ApproveLinkSheet(request: request),
  );
  return confirmed ?? false;
}

class _ApproveLinkSheet extends StatefulWidget {
  const _ApproveLinkSheet({required this.request});

  final IncomingLinkRequest request;

  @override
  State<_ApproveLinkSheet> createState() => _ApproveLinkSheetState();
}

class _ApproveLinkSheetState extends State<_ApproveLinkSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final text = consentTexts[ConsentPurpose.familySharing]!;
    final name = familyDisplayName(widget.request.familyName);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chấp thuận $name theo dõi bạn?', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.md),
            Text(text.title, style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.xs),
            Text(
              text.description,
              key: const Key('approve-consent-text'),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Chia sẻ với: $name',
              key: const Key('approve-share-with'),
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Sau khi chấp thuận, chia sẻ dữ liệu vẫn đang tắt cho tới khi bạn bật. Bạn có thể '
              'tắt chia sẻ hoặc hủy liên kết bất cứ lúc nào trong Hồ sơ > Người giám sát.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              key: const Key('approve-consent-checkbox'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              title: Text(
                'Tôi đồng ý chia sẻ dữ liệu như trên với $name',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('approve-confirm'),
              onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
              child: const Text('Chấp thuận'),
            ),
            TextButton(
              key: const Key('approve-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }
}
