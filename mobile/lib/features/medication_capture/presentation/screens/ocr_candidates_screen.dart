import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/ocr_models.dart';

class OcrCandidatesScreen extends StatelessWidget {
  const OcrCandidatesScreen(
      {super.key,
      required this.result,
      required this.onRetake,
      required this.onExit});
  final OcrMatchResult result;
  final VoidCallback onRetake, onExit;
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
                icon: const Icon(Icons.arrow_back))),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
              Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(title, style: AppTextStyles.heading)),
              const SizedBox(height: 16),
              Text(empty
                  ? 'Thử chụp rõ tên và hàm lượng trên bao bì.'
                  : 'Đây là các gợi ý từ danh mục. Hãy đối chiếu với bao bì; thuốc chưa được thêm vào form.'),
              if (result.reasons.contains('strength_unverified')) ...[
                const SizedBox(height: 12),
                const Text(
                    'Chưa xác minh được hàm lượng. Hãy đối chiếu hàm lượng in trên bao bì.')
              ],
              for (final c in result.items) ...[
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: AppTextStyles.bodyStrong),
                              const SizedBox(height: 8),
                              Text(
                                  'Hàm lượng: ${c.strengthText ?? 'Chưa có thông tin'}'),
                              Text(
                                  'Hoạt chất: ${c.activeIngredient ?? 'Chưa có thông tin'}'),
                              Text(
                                  'Dạng thuốc: ${c.dosageForm ?? 'Chưa có thông tin'}'),
                            ])))
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                  onPressed: onRetake, child: const Text('Chụp lại')),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: onExit, child: const Text('Quay về form')),
            ])));
  }
}
