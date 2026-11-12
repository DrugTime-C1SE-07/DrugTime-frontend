import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/profile_controller.dart';
import '../widgets/condition_catalog_sheet.dart';
import '../widgets/condition_editor_sheet.dart';
import '../widgets/profile_icons.dart';
import '../widgets/profile_notices.dart';

class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});
  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ProfileScope.read(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Thông tin y tế'),
          leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              icon: const ProfileIcon('p-arrow-left'))),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const ProfileNotices(),
                    if (c.loading && c.profile == null) const ProfileLoading(),
                    if (c.profile != null && !c.denied) ...[
                      const Text('BỆNH MÃN TÍNH / BỆNH NỀN',
                          style: AppTextStyles.captionStrong),
                      const SizedBox(height: 10),
                      if (c.profile!.conditions.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                                'Bạn chưa thêm bệnh nền. Chọn từ danh mục để cập nhật hồ sơ.'))
                      else
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          for (final item in c.profile!.conditions)
                            _ConditionChip(
                                key: Key('condition-chip-${item.id}'),
                                label: item.name,
                                onTap: c.saving
                                    ? null
                                    : () => showConditionEditor(context, item)),
                        ]),
                      const SizedBox(height: 12),
                      _AddConditionButton(
                          onPressed: c.saving || c.loading
                              ? null
                              : () => showConditionCatalog(context)),
                      const SizedBox(height: 16),
                      const Text(
                          'Nhấn vào bệnh đã thêm để sửa phân loại, giai đoạn hoặc xóa khỏi hồ sơ.',
                          style: AppTextStyles.caption),
                    ],
                  ]))),
    );
  }
}

/// Chip bệnh đã chọn theo Figma S08-2: cao 42, bo tròn hoàn toàn, nền `#01554F`,
/// chữ trắng 14 kèm icon check 13. Dùng `minHeight` để không cắt chữ khi người
/// dùng bật cỡ chữ lớn.
class _ConditionChip extends StatelessWidget {
  const _ConditionChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(14) <= 18;
    return Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: Ink(
                decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(999)),
                child: InkWell(
                    onTap: onTap,
                    child: Container(
                        constraints: BoxConstraints(
                            minHeight: compact ? 42 : 0, minWidth: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(
                              width: 13,
                              height: 13,
                              child: FittedBox(child: ProfileIcon('m-check'))),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _chipTextStyle))),
                        ]))))));
  }
}

const _chipTextStyle = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Colors.white);

/// Nút "Thêm bệnh khác" của Figma S08-2: viền đứt nét 4/4, cao 40, bo 12.
class _AddConditionButton extends StatelessWidget {
  const _AddConditionButton({required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(14) <= 18;
    final enabled = onPressed != null;
    return Semantics(
        button: true,
        enabled: enabled,
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(AppRadius.field),
                child: CustomPaint(
                    painter: _DashedBorderPainter(
                        color: enabled
                            ? AppColors.border
                            : AppColors.surfaceMuted),
                    child: Container(
                        constraints: BoxConstraints(
                            minHeight: compact ? 40 : 0,
                            minWidth: double.infinity),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const ProfileIcon('m-plus'),
                              const SizedBox(width: 6),
                              Flexible(
                                  child: Text('Thêm bệnh khác',
                                      style: AppTextStyles.captionStrong
                                          .copyWith(
                                              fontWeight: FontWeight.w400))),
                            ]))))));
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});
  final Color color;

  static const _dash = 4.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(AppRadius.field)));
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        canvas.drawPath(
            metric.extractPath(start, math.min(start + _dash, metric.length)),
            paint);
        start += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
