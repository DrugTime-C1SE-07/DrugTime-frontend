import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'mascot_rig.dart';

/// Original Figma artwork, articulated by the same blink/breath/joint rig.
/// Masks are normalized source coordinates; the texture is never flattened or
/// edited. At rest this draws the original pixels, including its shield/shading.
class MascotArtworkPainter extends CustomPainter {
  MascotArtworkPainter(this.rig, this.image, {required this.farewell})
      : super(repaint: rig);
  final MascotRig rig;
  final ui.Image image;
  final bool farewell;

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width, size.height);
    final source =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    const bounds = Rect.fromLTWH(0, 0, 1, 1);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    void texture() => c.drawImageRect(image, source, bounds, paint);
    // A gentle torso squash/breath; the arm rotation below has a different phase.
    final breath = rig.value('sq');
    c.translate(.5, .85);
    c.scale(1 + breath * .25, 1 - breath * .4);
    c.translate(-.5, -.85 + rig.value('y') / 600);
    final arm = Path();
    if (farewell) {
      arm.moveTo(.755, .25);
      arm.lineTo(1, .18);
      arm.lineTo(1, .60);
      arm.lineTo(.72, .60);
      arm.lineTo(.735, .51);
      arm.lineTo(.75, .45);
    } else {
      arm.moveTo(.795, .30);
      arm.lineTo(1, .25);
      arm.lineTo(1, .75);
      arm.lineTo(.71, .75);
      arm.lineTo(.755, .64);
      arm.lineTo(.78, .50);
    }
    arm.close();
    final eyes = farewell
        ? [
            const Rect.fromLTWH(.365, .300, .105, .125),
            const Rect.fromLTWH(.555, .305, .105, .125)
          ]
        : [
            const Rect.fromLTWH(.375, .265, .102, .15)
          ]; // The other eye is the original wink.
    final blink = rig.blink;
    final body = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addPath(arm, Offset.zero);
    if (blink < .99) {
      for (final eye in eyes) {
        body.addOval(eye);
      }
    }
    if (blink < .99) {
      for (final eye in eyes) {
        c.drawOval(
            eye.inflate(.006),
            Paint()
              ..shader = const LinearGradient(
                      colors: [Color(0xfff7f6f3), Color(0xfff2efec)])
                  .createShader(eye));
      }
    }
    c.save();
    c.clipPath(body, doAntiAlias: false);
    texture();
    c.restore();
    // The shoulder stays anchored. Fingers and thumb are the source artwork,
    // moving independently of the torso instead of translating the whole PNG.
    final pivot =
        farewell ? const Offset(.745, .545) : const Offset(.755, .655);
    final angle = farewell
        ? math.sin(rig.time * 4.5) * .11
        : math.sin(rig.time * 2) * .065;
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(angle);
    c.translate(-pivot.dx, -pivot.dy);
    c.clipPath(arm, doAntiAlias: false);
    texture();
    c.restore();
    if (blink < .99) {
      for (final eye in eyes) {
        // Skin is visible behind the eyelid only during the 140 ms blink.
        c.drawOval(
            eye,
            Paint()
              ..shader = const LinearGradient(
                      colors: [Color(0xfff7f6f3), Color(0xfff2efec)])
                  .createShader(eye));
        if (blink > .12) {
          c.save();
          c.translate(eye.center.dx, eye.center.dy);
          c.scale(1, blink);
          c.translate(-eye.center.dx, -eye.center.dy);
          c.clipPath(Path()..addOval(eye));
          texture();
          c.restore();
        } else {
          c.drawPath(
              Path()
                ..moveTo(eye.left + .018, eye.center.dy)
                ..quadraticBezierTo(eye.center.dx, eye.center.dy + .012,
                    eye.right - .018, eye.center.dy),
              Paint()
                ..color = const Color(0xff101832)
                ..style = PaintingStyle.stroke
                ..strokeWidth = .012
                ..strokeCap = StrokeCap.round);
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(MascotArtworkPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.farewell != farewell ||
      oldDelegate.rig != rig;
}
