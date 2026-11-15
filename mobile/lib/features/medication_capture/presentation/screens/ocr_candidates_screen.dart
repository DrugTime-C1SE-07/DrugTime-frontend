import '../../../medication/presentation/widgets/medication_step_progress.dart';
import 'camera_capture_screen.dart';
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
  });

  final OcrMatchResult result;
  final VoidCallback onRetake, onExit;
  final ValueChanged<OcrCandidate>? onSelectCandidate;

  @override
  Widget build(BuildContext context) {
    final empty = result.status == OcrMatchStatus.noMatch;
    final title = switch (result.status) {
      OcrMatchStatus.matched => 'Đã nhận diện thuốc',
      OcrMatchStatus.lowConfidence => 'Có thể là',
      OcrMatchStatus.noMatch => 'Chưa đọc được vỏ hộp',
    };

    final content = ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(title, style: AppTextStyles.heading),
        ),
        const SizedBox(height: 12),
        Text(
          empty
              ? 'Hãy quét lại theo gợi ý bên dưới.'
              : 'Đây là các gợi ý từ danh mục. Hãy đối chiếu với bao bì; chọn "Đúng thuốc này" để tiếp tục thiết lập lịch uống.',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        ),
        if (empty) ...[
          const SizedBox(height: 16),
          const Icon(Icons.search_rounded, size: 48, color: AppColors.brand),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined,
                        size: 20, color: AppColors.brand),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Đủ ánh sáng, không bị loá',
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                  ],
                ),
                Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.crop_free, size: 20, color: AppColors.brand),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tên thuốc nằm trong khung',
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetake,
            icon: const Icon(Icons.refresh),
            label: const Text('Quét lại'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onExit,
            child: const Text('Quay về tìm kiếm'),
          ),
        ] else ...[
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
          for (final c in result.items) ...[
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
                          child: Text(c.name, style: AppTextStyles.bodyStrong),
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
                    const SizedBox(height: 14),
                    const Text(
                      'Có đúng thuốc trên vỏ hộp không?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onRetake,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: const Text('Quét lại'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            key: ValueKey('ocr-confirm-${c.id}'),
                            onPressed: () {
                              if (onSelectCandidate != null) {
                                onSelectCandidate!(c);
                              } else {
                                onExit();
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('Đúng thuốc này'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: onExit,
              child: const Text('Quay về tìm kiếm'),
            ),
          ),
        ],
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả nhận diện'),
        leading: IconButton(
          tooltip: 'Quay về form',
          onPressed: onExit,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: empty
          ? SafeArea(
              child: Column(children: [
              const MedicationStepProgress(currentStep: 0),
              Expanded(child: content),
            ]))
          : CaptureSheetLayout(sheet: content),
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
