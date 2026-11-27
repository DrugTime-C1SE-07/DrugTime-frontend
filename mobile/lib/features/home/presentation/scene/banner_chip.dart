import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chip tóm tắt trên banner (số liều, chuỗi ngày...).
///
/// Viên cao 34 dp, nền trắng hơi trong, viền trắng mảnh, bóng mềm; icon trong vòng tròn
/// màu [tint], tuỳ chọn vòng tiến độ [progress] (0..1) quanh icon.
class BannerChip extends StatelessWidget {
  const BannerChip({
    super.key,
    required this.icon,
    required this.label,
    this.tint = const Color(0xFF16A052),
    this.progress,
  });

  static const height = 34.0;

  final IconData icon;
  final String label;
  final Color tint;
  final double? progress;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .86),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox.square(
            dimension: 24,
            child: CustomPaint(
              painter: _Ring(tint, progress),
              child: Center(child: Icon(icon, size: 14, color: tint)),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Color(0xFF19231F))),
        ]),
      );
}

class _Ring extends CustomPainter {
  _Ring(this.tint, this.progress);
  final Color tint;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = tint.withValues(alpha: .14));
    final p = progress;
    if (p == null) return;
    final rect = Rect.fromCircle(center: c, radius: r - 1.4);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        stroke..color = tint.withValues(alpha: .22));
    if (p > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * p.clamp(0.0, 1.0), false,
          stroke..color = tint);
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.tint != tint || old.progress != progress;
}

/// Nút kêu gọi chính trên banner (ví dụ "Bắt đầu nào!") kiểu nút Duolingo:
/// viên cam cao 44 dp, gờ đáy đậm hơn tạo khối, nhấn thì lún xuống; khi [bounce] bật thì
/// thỉnh thoảng nảy nhẹ để gợi ý bấm.
class BannerCtaButton extends StatefulWidget {
  const BannerCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.auto_awesome,
    this.bounce = true,
  });

  static const height = 44.0;
  static const _lip = 4.0;

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool bounce;

  @override
  State<BannerCtaButton> createState() => _BannerCtaButtonState();
}

class _BannerCtaButtonState extends State<BannerCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hint = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.bounce) _hint.repeat();
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const lip = BannerCtaButton._lip;
    const face = Color(0xFFFF8A3D);
    const edge = Color(0xFFE0661F);
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _hint,
          builder: (context, child) {
            // nảy nhẹ hai nhịp ở đầu mỗi chu kỳ, phần còn lại đứng yên
            final u = _hint.value;
            final hop =
                u < .16 ? math.sin(u / .16 * math.pi * 2).abs() * 3 : 0.0;
            return Transform.translate(offset: Offset(0, -hop), child: child);
          },
          child: SizedBox(
            height: BannerCtaButton.height,
            child: Stack(children: [
              // gờ đáy
              Positioned.fill(
                top: lip,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: edge,
                    borderRadius:
                        BorderRadius.circular(BannerCtaButton.height / 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x40E0661F),
                          blurRadius: 10,
                          offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 70),
                padding: EdgeInsets.only(
                    top: _down ? lip : 0, bottom: _down ? 0 : lip),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFA45C), face],
                    ),
                    borderRadius:
                        BorderRadius.circular(BannerCtaButton.height / 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.white),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
