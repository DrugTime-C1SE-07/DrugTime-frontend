import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/meal_ui.dart';

/// Hạt bụi sao của thiên hà xoắn 2 nhánh; sinh một lần theo seed (không cấp phát mỗi khung).
class _Star {
  _Star(this.r, this.theta0, this.size, this.color, this.tw);
  final double r, theta0, size, tw;
  final Color color;
}

final List<_Star> _stars = () {
  final rnd = math.Random(7);
  const palette = [
    MealColors.violet,
    MealColors.blue,
    MealColors.teal,
    MealColors.pink,
    Colors.white
  ];
  return List.generate(340, (i) {
    final arm = i % 2;
    final r = math.pow(rnd.nextDouble(), .75).toDouble() * .95 + .08;
    final jitter = (rnd.nextDouble() - .5) * (.9 - r * .4);
    final theta = arm * math.pi + r * 3.4 + jitter;
    final c = r < .3
        ? Color.lerp(const Color(0xFFFFE9B8), Colors.white, rnd.nextDouble())!
        : palette[rnd.nextInt(palette.length)];
    return _Star(r, theta, .9 + rnd.nextDouble() * rnd.nextDouble() * 3.2, c,
        rnd.nextDouble() * 6.28);
  });
}();

/// Ba quỹ đạo nghiêng đan nhau như prototype (xanh tím, xanh dương, teal).
const ringAngles = [0.0, math.pi / 3, -math.pi / 3];
const ringColors = [MealColors.blue, MealColors.violet, MealColors.teal];

/// Icon nguyên liệu chạy trên quỹ đạo: (tên, vòng, pha, màu vệt).
const orbitIcons = [
  ('mushroom', 1, 0.3, Color(0xFFE8453C)),
  ('carrot', 0, 1.4, Color(0xFFF57C22)),
  ('chicken', 2, 2.5, Color(0xFFD9853B)),
  ('egg', 1, 3.6, Color(0xFFFFC928)),
  ('salad', 0, 4.7, Color(0xFF5DBB4A)),
  ('rice', 2, 5.6, Color(0xFFE8453C)),
];

/// Vị trí một điểm trên vòng [ring] ở góc tham số [phi]; z > 0 là phía trước linh vật.
({Offset p, double z}) ringPoint(
    int ring, double phi, double t, double radius, Offset c) {
  final a = radius, b = radius * .34;
  final rho = ringAngles[ring] + t * .035;
  final lx = a * math.cos(phi), ly = b * math.sin(phi);
  return (
    p: c +
        Offset(lx * math.cos(rho) - ly * math.sin(rho),
            lx * math.sin(rho) + ly * math.cos(rho)),
    z: math.sin(phi),
  );
}

/// Góc hiện tại của icon thứ [i]; khi [collapse] tăng, quay nhanh dần (bị hút vào tâm).
double iconPhi(int i, double t, double collapse) {
  final (_, ring, phase, _) = orbitIcons[i];
  return phase + t * (.5 + ring * .06) + collapse * collapse * 9;
}

double collapseRadius(double collapse) =>
    1 - Curves.easeInCubic.transform(collapse.clamp(0, 1));

enum GalaxyLayer { back, front }

/// Vẽ một lớp của thiên hà: lớp sau (sau linh vật) hoặc lớp trước (mờ hơn, trước linh vật).
class GalaxyPainter extends CustomPainter {
  GalaxyPainter(
      {required this.t,
      required this.collapse,
      required this.layer,
      this.core = 1});

  final double t;
  final double collapse;
  final GalaxyLayer layer;

  /// Độ sáng lõi (lấy đà trước khi bùng sáng thì giảm).
  final double core;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide * .46;
    final k = collapseRadius(collapse);
    final fade = 1 - math.pow(collapse, 3).toDouble();
    final front = layer == GalaxyLayer.front;

    if (!front) {
      // quầng tím lớn + lõi sáng ấm "thở"
      canvas.drawCircle(
          c,
          radius * 1.25,
          Paint()
            ..shader = RadialGradient(colors: [
              MealColors.violet.withValues(alpha: .28 * fade),
              MealColors.violet.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: c, radius: radius * 1.25)));
      final pulse = 1 + .05 * math.sin(t * 2.2);
      final coreR = radius * .62 * pulse * (.5 + .5 * k) * core;
      canvas.drawCircle(
          c,
          coreR,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFFFFBEF).withValues(alpha: .95 * core),
              const Color(0xFFFFE7B0).withValues(alpha: .45 * core),
              const Color(0xFFFFE7B0).withValues(alpha: 0),
            ], stops: const [
              0,
              .45,
              1
            ]).createShader(Rect.fromCircle(center: c, radius: coreR)));
    }

    if (!front) {
      // dải tinh vân mờ dọc đĩa thiên hà (tím–hồng một phía, teal phía kia), xoay chậm
      for (final (ang, col, dx) in [
        (t * .06, MealColors.violet, -.18),
        (t * .06 + math.pi, MealColors.teal, .2)
      ]) {
        canvas.save();
        canvas.translate(c.dx + math.cos(ang) * radius * .35 * k,
            c.dy + math.sin(ang) * radius * .12 * k);
        canvas.rotate(-.18);
        final rect = Rect.fromCenter(
            center: Offset(dx * radius, 0),
            width: radius * 2.1 * k,
            height: radius * .55 * k);
        canvas.drawOval(
            rect,
            Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26)
              ..shader = RadialGradient(colors: [
                col.withValues(alpha: .30 * fade),
                MealColors.pink.withValues(alpha: .12 * fade),
                col.withValues(alpha: 0),
              ]).createShader(rect));
        canvas.restore();
      }
    }

    // bụi sao xoắn ốc
    final dot = Paint();
    final discR = radius * 1.18 * k;
    for (final s in _stars) {
      final omega = .32 / (.35 + s.r);
      final th = s.theta0 + t * omega + collapse * collapse * 8;
      final z = math.sin(th);
      if ((z >= 0) != front) continue;
      // số mũ không được âm: k = 0 (co hết) với s.r > 1 sẽ thành 0^âm = ∞ → toạ độ NaN
      final rr = s.r * math.pow(k, .3 * (1 - s.r).clamp(0.0, 1.0)).toDouble();
      final p = c +
          Offset(discR * rr * math.cos(th), discR * rr * math.sin(th) * .42);
      final tw = .55 + .45 * math.sin(t * 2.6 + s.tw);
      var a = (front ? .55 : .95) * tw * fade;
      if (front) {
        // trong vùng quả cầu: mờ hẳn, không nhấp nháy trước mặt linh vật
        final d = (p - c).distance / (radius * .5);
        if (d < 1) a = .12 * fade * d;
      }
      dot.color = s.color.withValues(alpha: a);
      canvas.drawCircle(p, s.size * (front ? 1.15 : 1), dot);
      if (s.size > 2.6) {
        // sao sáng có quầng
        dot.color = s.color.withValues(alpha: a * .25);
        canvas.drawCircle(p, s.size * 2.6, dot);
      }
    }

    // quỹ đạo: vẽ nửa sau ở lớp sau, nửa trước ở lớp trước
    final ringR = radius * k;
    if (ringR > 2) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var ring = 0; ring < 3; ring++) {
        const n = 72;
        var prev = ringPoint(ring, 0, t, ringR, c);
        for (var j = 1; j <= n; j++) {
          final cur = ringPoint(ring, j / n * 2 * math.pi, t, ringR, c);
          final z = (prev.z + cur.z) / 2;
          if ((z >= 0) == front) {
            pen
              ..strokeWidth = 1.2 + .9 * (z + 1) / 2
              ..color = ringColors[ring]
                  .withValues(alpha: (.28 + .42 * (z + 1) / 2) * fade);
            canvas.drawLine(prev.p, cur.p, pen);
          }
          prev = cur;
        }
      }
      // vệt sáng đuôi của từng icon
      for (var i = 0; i < orbitIcons.length; i++) {
        final (_, ring, _, color) = orbitIcons[i];
        final phi = iconPhi(i, t, collapse);
        for (var j = 1; j <= 7; j++) {
          final q =
              ringPoint(ring, phi - j * .055 * (1 + collapse * 3), t, ringR, c);
          if ((q.z >= 0) != front) continue;
          dot.color = color.withValues(alpha: (.32 * (1 - j / 8)) * fade);
          canvas.drawCircle(q.p, 4.2 * (1 - j / 9) * (.8 + .3 * q.z), dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(GalaxyPainter old) =>
      old.t != t || old.collapse != collapse || old.core != core;
}

/// Toàn cảnh thiên hà quanh linh vật: lớp sau → icon phía sau → quả cầu + linh vật → icon phía trước → lớp trước.
class GalaxyStage extends StatelessWidget {
  const GalaxyStage({
    super.key,
    required this.t,
    required this.collapse,
    required this.mascot,
    this.core = 1,
    this.mascotSpin = 0,
  });

  final double t;
  final double collapse;
  final double core;
  final double mascotSpin;
  final Widget mascot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final c = size.center(Offset.zero);
      final radius = size.shortestSide * .46;
      final ringR = radius * collapseRadius(collapse);
      final sphere = radius * .92;
      final back = <Widget>[], front = <Widget>[];
      for (var i = 0; i < orbitIcons.length; i++) {
        final (name, ring, _, _) = orbitIcons[i];
        final q = ringPoint(ring, iconPhi(i, t, collapse), t, ringR, c);
        final depth = (q.z + 1) / 2;
        final s = (.74 + .38 * depth) * (1 - collapse * .75);
        final a =
            ((.5 + .5 * depth) * (1 - math.pow(collapse, 2.5))).clamp(0.0, 1.0);
        const icon = 38.0;
        // key cố định: icon đổi lớp sau/trước thì thứ tự con đổi, không có key Flutter sẽ ghép nhầm
        // Positioned của icon với của quả cầu → dựng lại linh vật (bị "nháy")
        final w = Positioned(
          key: ValueKey('orbit-icon-$i'),
          left: q.p.dx - icon / 2,
          top: q.p.dy - icon / 2,
          child: Opacity(
            opacity: a.toDouble(),
            child: Transform.rotate(
              angle: math.sin(t * 1.3 + i) * .18 + collapse * 6,
              child:
                  Transform.scale(scale: s, child: FoodIcon(name, size: icon)),
            ),
          ),
        );
        (q.z >= 0 ? front : back).add(w);
      }
      final mk = 1 - Curves.easeInCubic.transform(collapse);
      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          key: const ValueKey('galaxy-back'),
          child: RepaintBoundary(
            child: CustomPaint(
                painter: GalaxyPainter(
                    t: t,
                    collapse: collapse,
                    layer: GalaxyLayer.back,
                    core: core)),
          ),
        ),
        ...back,
        Positioned(
          key: const ValueKey('galaxy-sphere'),
          left: c.dx - sphere / 2,
          top: c.dy - sphere / 2,
          width: sphere,
          height: sphere,
          child: Opacity(
            opacity: mk.clamp(0, 1),
            child: Transform.rotate(
              angle: mascotSpin,
              child: Transform.scale(
                  scale: .25 + .75 * mk, child: _GlassSphere(child: mascot)),
            ),
          ),
        ),
        ...front,
        Positioned.fill(
          key: const ValueKey('galaxy-front'),
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                  painter: GalaxyPainter(
                      t: t, collapse: collapse, layer: GalaxyLayer.front)),
            ),
          ),
        ),
      ]);
    });
  }
}

class _GlassSphere extends StatelessWidget {
  const _GlassSphere({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final d = box.maxWidth;
        return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-.3, -.35),
                    colors: [
                      Colors.white.withValues(alpha: .85),
                      const Color(0xFFF2EEFF).withValues(alpha: .65),
                      const Color(0xFFDDF3EE).withValues(alpha: .55),
                    ],
                    stops: const [0, .6, 1],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .9), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: MealColors.violet.withValues(alpha: .25),
                        blurRadius: 30,
                        spreadRadius: 2),
                  ],
                ),
              ),
              Positioned(
                left: d * .16,
                top: d * .1,
                child: Container(
                  width: d * .26,
                  height: d * .1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(d),
                    color: Colors.white.withValues(alpha: .7),
                  ),
                ),
              ),
              Positioned(
                top: d * .02,
                child: SizedBox(width: d * .98, height: d * .98, child: child),
              ),
            ]);
      });
}
