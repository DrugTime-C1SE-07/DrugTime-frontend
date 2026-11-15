import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';

enum DosageFormType {
  tablet,
  capsule,
  liquid,
  powder,
  drops,
  spray,
  cream,
  injection,
  other,
}

DosageFormType parseDosageForm(String? raw) {
  if (raw == null || raw.trim().isEmpty) return DosageFormType.other;
  final s = raw.toLowerCase().trim();
  if (s.contains('nang') || s.contains('capsule')) {
    return DosageFormType.capsule;
  }
  if (s.contains('bột') ||
      s.contains('cốm') ||
      s.contains('gói') ||
      s.contains('powder') ||
      s.contains('sachet')) {
    return DosageFormType.powder;
  }
  if (s.contains('nén') ||
      s.contains('tablet') ||
      s.contains('viên') ||
      s.contains('sủi') ||
      s.contains('ngậm')) {
    return DosageFormType.tablet;
  }
  if (s.contains('siro') ||
      s.contains('syrup') ||
      s.contains('dung dịch') ||
      s.contains('hỗn dịch') ||
      s.contains('nhũ dịch') ||
      s.contains('nước')) {
    return DosageFormType.liquid;
  }
  if (s.contains('nhỏ') || s.contains('drop') || s.contains('giọt')) {
    return DosageFormType.drops;
  }
  if (s.contains('xịt') || s.contains('spray') || s.contains('khí dung')) {
    return DosageFormType.spray;
  }
  if (s.contains('bôi') ||
      s.contains('kem') ||
      s.contains('gel') ||
      s.contains('mỡ') ||
      s.contains('cream') ||
      s.contains('ointment')) {
    return DosageFormType.cream;
  }
  if (s.contains('tiêm') || s.contains('inject')) {
    return DosageFormType.injection;
  }
  return DosageFormType.other;
}

/// Icon biểu thị dạng bào chế của thuốc (viên nén, viên nang, siro, gói bột, v.v.).
/// Mặc định dùng màu thương hiệu chuẩn theo thiết kế Figma, không yêu cầu chọn thủ công.
class DosageFormIcon extends StatelessWidget {
  const DosageFormIcon({
    super.key,
    this.dosageForm,
    this.size = 24,
    this.color = AppColors.brand,
    this.backgroundColor,
  });

  final String? dosageForm;
  final double size;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final type = parseDosageForm(dosageForm);
    if (backgroundColor case final bg?) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        alignment: Alignment.center,
        child: _buildIcon(type, size * 0.65),
      );
    }
    return _buildIcon(type, size);
  }

  Widget _buildIcon(DosageFormType type, double size) {
    switch (type) {
      case DosageFormType.capsule:
        return PillIcon(size: size, color: color);
      case DosageFormType.tablet:
        return CustomPaint(
          size: Size.square(size),
          painter: _TabletPainter(color),
        );
      case DosageFormType.liquid:
        return Icon(Icons.water_drop_outlined, size: size, color: color);
      case DosageFormType.powder:
        return Icon(Icons.inventory_2_outlined, size: size, color: color);
      case DosageFormType.drops:
        return Icon(Icons.opacity_outlined, size: size, color: color);
      case DosageFormType.spray:
        return Icon(Icons.air_outlined, size: size, color: color);
      case DosageFormType.cream:
        return Icon(Icons.spa_outlined, size: size, color: color);
      case DosageFormType.injection:
        return Icon(Icons.vaccines_outlined, size: size, color: color);
      case DosageFormType.other:
        return PillIcon(size: size, color: color);
    }
  }
}

class _TabletPainter extends CustomPainter {
  _TabletPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 9 * s;
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      Offset(center.dx - radius + 2 * s, center.dy),
      Offset(center.dx + radius - 2 * s, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TabletPainter oldDelegate) => oldDelegate.color != color;
}

/// Ô vuông bo góc chứa [DosageFormIcon] đại diện cho dạng thuốc.
class DosageFormTile extends StatelessWidget {
  const DosageFormTile({
    super.key,
    this.dosageForm,
    this.size = 48,
    this.color = AppColors.brand,
    this.muted = false,
  });

  final String? dosageForm;
  final double size;
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceMuted : AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: DosageFormIcon(
        dosageForm: dosageForm,
        size: size / 2,
        color: muted ? AppColors.inkDisabled : color,
      ),
    );
  }
}
