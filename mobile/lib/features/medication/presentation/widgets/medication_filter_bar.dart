import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/selectable_pill.dart';

enum MedicationFilter {
  all('Tất cả'),
  active('Đang dùng'),
  stopped('Đã ngừng');

  const MedicationFilter(this.label);

  final String label;
}

class MedicationFilterBar extends StatelessWidget {
  const MedicationFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final MedicationFilter selected;
  final Map<MedicationFilter, int> counts;
  final ValueChanged<MedicationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    // Wrap thay vì cuộn ngang: không có lựa chọn nào bị khuất ngoài màn hình,
    // kể cả khi người dùng phóng to chữ.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final filter in MedicationFilter.values)
          SelectablePill(
            label: '${filter.label} · ${counts[filter] ?? 0}',
            selected: filter == selected,
            minHeight: 44,
            onTap: () => onChanged(filter),
          ),
      ],
    );
  }
}
