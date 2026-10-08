import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../widgets/legal_texts.dart';

/// Màn đọc Điều khoản dịch vụ hoặc Chính sách quyền riêng tư (mở từ ô tick ở màn đăng nhập,
/// màn "Điều khoản đã cập nhật" và màn Quyền riêng tư).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(document.title), backgroundColor: AppColors.canvas),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              'Phiên bản ${document.version} · Hiệu lực từ ${document.effectiveDate}',
              key: const Key('legal-version'),
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
            ),
            if (document.intro case final intro?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(intro, style: AppTextStyles.body),
            ],
            for (final section in document.sections) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(section.heading, style: AppTextStyles.heading),
              for (final paragraph in section.paragraphs) ...[
                const SizedBox(height: AppSpacing.sm),
                _Paragraph(paragraph),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    if (!text.startsWith('- ')) return Text(text, style: AppTextStyles.body);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: AppTextStyles.body),
        Expanded(child: Text(text.substring(2), style: AppTextStyles.body)),
      ],
    );
  }
}
