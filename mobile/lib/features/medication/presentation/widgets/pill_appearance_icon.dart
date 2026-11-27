import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/pill_appearance.dart';
import 'dosage_form_icon.dart';

/// Icon thuốc theo hình và màu người bệnh chọn (S07-M2b). Chưa chọn gì thì dùng
/// [DosageFormIcon] suy từ dạng bào chế như trước. Chỉ chọn màu thì hình lấy theo gợi ý từ
/// dạng bào chế.
class PillAppearanceIcon extends StatelessWidget {
  const PillAppearanceIcon({
    super.key,
    this.shape,
    this.color,
    this.dosageForm,
    this.size = 28,
  });

  final PillShape? shape;
  final PillColor? color;
  final String? dosageForm;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (shape == null && color == null) {
      return DosageFormIcon(dosageForm: dosageForm, size: size);
    }
    final s = shape ?? PillShape.suggestFor(dosageForm);
    final fill = (color ?? PillColor.white).color;
    return Semantics(
      label: [s.label, if (color != null) color!.label].join(', '),
      image: true,
      child: switch (s) {
        PillShape.capsule ||
        PillShape.roundTablet ||
        PillShape.oblongTablet ||
        PillShape.softgel ||
        PillShape.effervescent =>
          CustomPaint(size: Size.square(size), painter: PillPainter(s, fill)),
        _ => Icon(_iconFor(s), size: size, color: _darken(fill)),
      },
    );
  }

  static IconData _iconFor(PillShape s) => switch (s) {
        PillShape.powderSachet => Icons.inventory_2_rounded,
        PillShape.syrup => Icons.local_drink_rounded,
        PillShape.drops => Icons.water_drop_rounded,
        PillShape.spray => Icons.air_rounded,
        PillShape.injectionPen => Icons.vaccines_rounded,
        PillShape.topical => Icons.sanitizer_rounded,
        _ => Icons.medication_rounded,
      };

  /// Màu nhạt (trắng, vàng) cần viền/nét đậm hơn để còn thấy trên nền sáng.
  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(math.min(hsl.lightness, 0.45)).toColor();
  }
}

/// Vẽ các dạng viên: viên nang hai nửa (màu đã chọn + trắng), viên tròn có vạch bẻ, viên dài,
/// nang mềm bóng và viên sủi có bọt.
class PillPainter extends CustomPainter {
  const PillPainter(this.shape, this.fill);

  final PillShape shape;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.06)
      ..color = AppColors.brand;
    final body = Paint()..color = fill;
    final c = Offset(w / 2, size.height / 2);

    switch (shape) {
      case PillShape.capsule:
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-math.pi / 4);
        final rect = Rect.fromCenter(
            center: Offset.zero, width: w * 0.92, height: w * 0.42);
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.21));
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(rect.left, rect.top, 0, rect.bottom));
        canvas.drawRRect(rr, body);
        canvas.restore();
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, rect.top, rect.right, rect.bottom));
        canvas.drawRRect(rr, Paint()..color = const Color(0xFFF9FAFA));
        canvas.restore();
        canvas.drawRRect(rr, outline);
        canvas.drawLine(Offset(0, rect.top), Offset(0, rect.bottom), outline);
        canvas.restore();
      case PillShape.roundTablet:
        final r = w * 0.4;
        canvas.drawCircle(c, r, body);
        canvas.drawCircle(c, r, outline);
        canvas.drawLine(
            c - Offset(r * 0.6, 0), c + Offset(r * 0.6, 0), outline);
      case PillShape.oblongTablet:
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-math.pi / 6);
        final rr = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: w * 0.9, height: w * 0.4),
            Radius.circular(w * 0.2));
        canvas.drawRRect(rr, body);
        canvas.drawRRect(rr, outline);
        canvas.drawLine(Offset(0, -w * 0.12), Offset(0, w * 0.12), outline);
        canvas.restore();
      case PillShape.softgel:
        final oval =
            Rect.fromCenter(center: c, width: w * 0.86, height: w * 0.56);
        canvas.drawOval(oval, body);
        canvas.drawOval(oval, outline);
        canvas.drawArc(
          oval.deflate(w * 0.12),
          math.pi * 1.1,
          math.pi * 0.35,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w * 0.06
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      case PillShape.effervescent:
        final r = w * 0.34;
        final center = c + Offset(-w * 0.06, w * 0.06);
        canvas.drawCircle(center, r, body);
        canvas.drawCircle(center, r, outline);
        for (final (dx, dy, br) in [
          (0.36, -0.36, 0.07),
          (0.24, -0.46, 0.045),
          (0.42, -0.2, 0.04)
        ]) {
          canvas.drawCircle(c + Offset(w * dx, w * dy), w * br, outline);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(PillPainter old) => old.shape != shape || old.fill != fill;
}

/// Ô vuông bo góc chứa [PillAppearanceIcon], cùng kích thước với `DosageFormTile`.
class PillAppearanceTile extends StatelessWidget {
  const PillAppearanceTile({
    super.key,
    this.shape,
    this.color,
    this.dosageForm,
    this.size = 48,
    this.muted = false,
    this.background,
  });

  final PillShape? shape;
  final PillColor? color;
  final String? dosageForm;
  final double size;
  final bool muted;

  /// Nền ô; `null` = kem mặc định.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    if (shape == null && color == null) {
      return DosageFormTile(dosageForm: dosageForm, size: size, muted: muted);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted
            ? AppColors.surfaceMuted
            : background ?? const Color(0xFFFFF0DF),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Opacity(
        opacity: muted ? 0.5 : 1,
        child: PillAppearanceIcon(
          shape: shape,
          color: color,
          dosageForm: dosageForm,
          size: size * 0.62,
        ),
      ),
    );
  }
}
