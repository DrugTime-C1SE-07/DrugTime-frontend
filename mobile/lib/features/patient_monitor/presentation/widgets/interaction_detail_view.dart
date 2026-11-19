import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../interaction_check/domain/entities/interaction_check_result.dart';

String handlingLabel(String value) => switch (value) {
      'tranh_phoi_hop' => 'Tránh phối hợp',
      'can_theo_doi' => 'Cần theo dõi',
      'cach_gio' => 'Dùng cách giờ theo hướng dẫn chuyên môn',
      'giam_lieu' => 'Hỏi bác sĩ hoặc dược sĩ về điều chỉnh liều',
      _ => 'Hỏi bác sĩ hoặc dược sĩ về cách xử lý',
    };

String foodStatusLabel(Object? status) => switch (status) {
      'co_tuong_tac' => 'Có tương tác',
      'da_kiem_tra_khong_thay' => 'Đã kiểm tra, không thấy tương tác',
      _ => 'Chưa đủ dữ liệu',
    };

/// R5a · Cảnh báo tương tác. Nội dung lấy nguyên từ kết quả engine tất định (bất biến 6),
/// giữ đủ ba trạng thái: có tương tác / đã kiểm tra không thấy / chưa đủ dữ liệu.
class InteractionDetailView extends StatelessWidget {
  const InteractionDetailView(
      {super.key, required this.drugs, required this.food});

  final InteractionCheckResult drugs;
  final Map<String, dynamic> food;

  @override
  Widget build(BuildContext context) {
    final medications = (food['medications'] as List).cast<Map>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _status('Thuốc – thuốc', drugs.status.label),
      for (final finding in drugs.interactions)
        _WarningCard(
          key: ValueKey(
              'finding-${finding.ingredientAId}-${finding.ingredientBId}'),
          level: finding.severityLevel,
          title: handlingLabel(finding.handlingType),
          pair: '${finding.ingredientAName} ⇄ ${finding.ingredientBName}',
          lines: [
            (Icons.info_outline, finding.description),
            (Icons.check, finding.warningMessage),
            if (finding.minIntervalHours != null)
              (
                Icons.schedule,
                'Cách nhau ít nhất ${_hours(finding.minIntervalHours!)} giờ'
              ),
          ],
          source: finding.source,
        ),
      for (final missing in drugs.insufficientDataMedications)
        _note('${missing.medicationName}: ${missing.reason}'),
      const SizedBox(height: 8),
      _status('Thuốc – thực phẩm', foodStatusLabel(food['status'])),
      for (final medication in medications)
        for (final warning in (medication['warnings'] as List).cast<Map>())
          _WarningCard(
            level: warning['severity_level'] as int? ?? 0,
            title: 'Cần theo dõi',
            pair:
                '${medication['medication']['name']} ⇄ ${warning['food_to_avoid']}',
            lines: [(Icons.info_outline, '${warning['reason']}')],
            source: '${warning['source']}',
          ),
      for (final medication in medications)
        if (medication['status'] == 'khong_du_du_lieu')
          _note(
              '${medication['medication']['name']}: ${foodStatusLabel(medication['status'])}'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_outlined, color: AppColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                [drugs.disclaimer, food['disclaimer'] as String? ?? '']
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .join('\n'),
                style: AppTextStyles.caption),
          ),
        ]),
      ),
    ]);
  }

  static String _hours(double h) =>
      h == h.roundToDouble() ? '${h.round()}' : '$h';

  Widget _status(String title, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title, style: AppTextStyles.heading)),
          const SizedBox(width: 8),
          Flexible(
              child: Text(label,
                  textAlign: TextAlign.end, style: AppTextStyles.caption)),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppTextStyles.caption),
      );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    super.key,
    required this.level,
    required this.title,
    required this.pair,
    required this.lines,
    required this.source,
  });

  final int level;
  final String title, pair, source;
  final List<(IconData, String)> lines;

  @override
  Widget build(BuildContext context) {
    const fg = AppColors.cautionText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3D88A), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFB4561E),
                borderRadius: BorderRadius.circular(12)),
            child: Text('MỨC $level',
                style:
                    AppTextStyles.captionStrong.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: AppTextStyles.bodyStrong.copyWith(color: fg))),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Text(pair, style: AppTextStyles.bodyStrong),
        ),
        for (final (icon, text) in lines)
          if (text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(text,
                        style: AppTextStyles.body.copyWith(color: fg))),
              ]),
            ),
        const SizedBox(height: 8),
        Text('Nguồn: $source', style: AppTextStyles.caption),
      ]),
    );
  }
}
