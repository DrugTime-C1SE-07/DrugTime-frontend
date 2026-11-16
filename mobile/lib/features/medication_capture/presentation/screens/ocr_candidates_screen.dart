import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/ocr_models.dart';

class OcrCandidatesScreen extends StatelessWidget {
  const OcrCandidatesScreen({
    super.key,
    required this.result,
    required this.onRetake,
    required this.onExit,
    this.onSelectCandidate,
    this.onManualSearch,
    this.onShowSuggestions,
    this.showCandidates = true,
  });

  final OcrMatchResult result;
  final VoidCallback onRetake, onExit;
  final ValueChanged<OcrCandidate>? onSelectCandidate;
  final VoidCallback? onManualSearch, onShowSuggestions;
  final bool showCandidates;

  @override
  Widget build(BuildContext context) {
    final empty = result.status == OcrMatchStatus.noMatch;
    final title = switch (result.status) {
      OcrMatchStatus.matched => 'Tìm thấy ứng viên',
      OcrMatchStatus.lowConfidence => 'Có thể là',
      OcrMatchStatus.noMatch => 'Chưa tìm thấy thuốc phù hợp',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả nhận diện'),
        leading: IconButton(
          tooltip: 'Quay về form',
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(title, style: AppTextStyles.heading),
            ),
            const SizedBox(height: 16),
            Text(
              empty
                  ? 'Thử chụp rõ tên và hàm lượng trên bao bì.'
                  : 'Đây là các gợi ý từ danh mục. Hãy đối chiếu với bao bì; chọn "Đúng thuốc này" để tiếp tục thiết lập lịch uống.',
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
            ),
            if (result.reasons.contains('strength_unverified')) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cautionBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.caution, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chưa xác minh được hàm lượng. Hãy đối chiếu hàm lượng in trên bao bì.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.cautionText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onManualSearch != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onManualSearch,
                  child: const Text('Tìm thuốc thủ công')),
            ],
            if (onShowSuggestions != null && !showCandidates)
              TextButton(
                  onPressed: onShowSuggestions,
                  child: const Text('Xem gợi ý khác')),
            for (final c
                in showCandidates ? result.items : const <OcrCandidate>[]) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                Text(c.name, style: AppTextStyles.bodyStrong),
                          ),
                          if (c.score > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(c.score * 100).round()}% khớp',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (c.strengthText != null &&
                              c.strengthText!.isNotEmpty)
                            _TagChip(label: 'Hàm lượng: ${c.strengthText}'),
                          if (c.dosageForm != null && c.dosageForm!.isNotEmpty)
                            _TagChip(label: 'Dạng: ${c.dosageForm}'),
                          if (c.activeIngredient != null &&
                              c.activeIngredient!.isNotEmpty)
                            _TagChip(label: 'Hoạt chất: ${c.activeIngredient}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (onSelectCandidate != null) {
                              onSelectCandidate!(c);
                            } else {
                              onExit();
                            }
                          },
                          icon:
                              const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Đúng thuốc này'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetake,
              child: const Text('Chụp lại'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onExit,
              child: const Text('Quay về form'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}
