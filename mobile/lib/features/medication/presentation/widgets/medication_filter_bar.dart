import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

enum MedicationFilter {
  all('Tất cả'),
  active('Đang dùng'),
  stopped('Đã ngừng');

  const MedicationFilter(this.label);

  final String label;

  /// Nền cố định của từng chip (Figma node 32:4243).
  Color get background => switch (this) {
        MedicationFilter.all => AppColors.surfaceMuted,
        MedicationFilter.active => AppColors.safeBg,
        MedicationFilter.stopped => AppColors.dangerBg,
      };
}

/// Hàng chip lọc của S06 (Figma node 32:4243).
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

  static const _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);

    // Ba chip luôn nằm trên một hàng. Vừa chỗ thì giữ độ rộng tự nhiên như
    // Figma; không vừa (chữ phóng to) thì co theo tỉ lệ và cho nhãn xuống dòng
    // bao nhiêu cũng được, để không chip nào rớt hàng và không chữ nào bị cắt.
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = [
          for (final f in MedicationFilter.values)
            _FilterChip.naturalWidth(f.label, counts[f] ?? 0, baseStyle, scaler),
        ];
        final total = widths.fold<double>(0, (sum, w) => sum + w) +
            _gap * (MedicationFilter.values.length - 1);
        final fits = total <= constraints.maxWidth;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, f) in MedicationFilter.values.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                if (fits)
                  _chip(f)
                else
                  Expanded(flex: widths[i].round(), child: _chip(f)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chip(MedicationFilter filter) => _FilterChip(
        name: filter.label,
        count: counts[filter] ?? 0,
        background: filter.background,
        selected: filter == selected,
        onTap: () => onChanged(filter),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.name,
    required this.count,
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final Color background;
  final bool selected;
  final VoidCallback onTap;

  /// Phần nhìn thấy cao ~35 theo Figma; vùng chạm vẫn đủ lớn cho người lớn tuổi.
  static const _minTapHeight = 44.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm);
  static const _borderWidth = 1.5;
  static const _nameStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.45);
  static const _countStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.45);

  static TextSpan _label(String name, int count, TextStyle base, Color color) => TextSpan(
        children: [
          TextSpan(text: name, style: base.merge(_nameStyle).copyWith(color: color)),
          TextSpan(text: ' · $count', style: base.merge(_countStyle).copyWith(color: color)),
        ],
      );

  /// Độ rộng chip khi nhãn nằm trên một dòng. Luôn tính cả viền để độ rộng
  /// không nhảy khi đổi chip đang chọn; cộng dư 1 cho sai số làm tròn.
  static double naturalWidth(String name, int count, TextStyle base, TextScaler scaler) {
    final painter = TextPainter(
      text: _label(name, count, base, AppColors.ink),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble() + _padding.horizontal + 2 * _borderWidth + 1;
  }

  @override
  Widget build(BuildContext context) {
    // Đang chọn: chữ màu thương hiệu + viền, không chỉ dựa vào màu.
    final color = selected ? AppColors.brand : AppColors.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $count thuốc',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapHeight),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: _padding,
              decoration: ShapeDecoration(
                color: background,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected ? AppColors.brand : Colors.transparent,
                    width: _borderWidth,
                  ),
                ),
              ),
              child: Text.rich(
                _label(name, count, DefaultTextStyle.of(context).style, color),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
