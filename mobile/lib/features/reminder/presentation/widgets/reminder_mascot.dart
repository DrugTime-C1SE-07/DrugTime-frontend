import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../home/presentation/scene/chibi_painter.dart';
import '../../../home/presentation/scene/chibi_pet.dart';
import '../../../home/presentation/scene/living_banner.dart';

/// Sau bao lâu không thao tác thì pet chuyển sang sốt ruột ([PetMood.stomp]).
const reminderMascotIdleBeforeStomp = 60.0;

/// Thời lượng phản ứng khi chạm vào pet.
const _pokeSeconds = .8;

/// Chu kỳ một đợt confetti khi ăn mừng.
const _confettiPeriod = 2.6; // khớp ReminderMascot.celebrateDuration

/// Động tác riêng theo buổi (giờ Việt Nam), xen vào chu kỳ nhắc:
/// sáng vươn vai, trưa vẫy tay chào, chiều ngó lên trời, tối ngáp.
PetMood reminderDayPartMood(int hourVn) {
  if (hourVn >= 5 && hourVn < 10) return PetMood.stretch;
  if (hourVn >= 10 && hourVn < 15) return PetMood.wave;
  if (hourVn >= 15 && hourVn < 18) return PetMood.thinking;
  return PetMood.yawn;
}

/// Chọn tư thế pet ở màn nhắc thuốc. Thuần để test được.
///
/// Ưu tiên: đã uống → ăn mừng; có lỗi → lo lắng; giảm chuyển động → ôm trước ngực;
/// lâu không thao tác → sốt ruột. Còn lại chu kỳ 6 giây: chỉ tay, ôm trước ngực như lớp
/// nhắc ở Trang chủ, rồi động tác theo buổi ([reminderDayPartMood]).
PetMood reminderPetMood({
  required bool confirmed,
  required bool hasError,
  required bool still,
  required double time,
  required double idleSeconds,
  required int hourVn,
}) {
  if (confirmed) return PetMood.celebrate;
  if (hasError) return PetMood.concerned;
  if (still) return PetMood.hold;
  if (idleSeconds >= reminderMascotIdleBeforeStomp) return PetMood.stomp;
  final phase = time % 6;
  if (phase < 2) return PetMood.point;
  if (phase < 4) return PetMood.hold;
  return reminderDayPartMood(hourVn);
}

/// Pet chibi của Trang chủ đứng trên đồi cỏ, nhắc uống thuốc ở màn toàn màn hình.
///
/// Chỉ trang trí: không thay thế nút nào. Tự dừng khi route bị che (`TickerMode`),
/// đứng yên khi bật "Giảm chuyển động" hoặc khi [LivingBanner.autoplay] tắt (test).
class ReminderMascot extends StatefulWidget {
  const ReminderMascot({
    super.key,
    required this.scheduledAt,
    required this.confirmed,
    required this.hasError,
    required this.now,
    this.height = 190,
  });

  /// Khoảng cách từ chân pet tới đáy widget; màn dùng để đặt mặt cỏ của cảnh nền.
  static const feetInset = 22.0;

  /// Một lượt ăn mừng trọn vẹn (nhảy + một đợt confetti); màn đợi xong mới tự đóng.
  static const celebrateDuration = Duration(milliseconds: 2600);

  /// Khi không có hoạt họa: giữ khung ăn mừng tĩnh đủ lâu để kịp thấy.
  static const celebrateStillHold = Duration(milliseconds: 1500);

  /// Giờ hiện tại (UTC), quyết định động tác theo buổi.
  final DateTime now;

  /// Giờ dự kiến (UTC), vẽ lên đồng hồ pet cầm.
  final DateTime scheduledAt;
  final bool confirmed;
  final bool hasError;
  final double height;

  @override
  State<ReminderMascot> createState() => _ReminderMascotState();
}

class _ReminderMascotState extends State<ReminderMascot>
    with SingleTickerProviderStateMixin {
  final _ctl = PetController();
  final _rig = ChibiRig();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  bool _still = false;
  double _idleSince = 0;
  double _pokeUntil = -1;
  double _celebrateSince = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = !LivingBanner.autoplay ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
      _step(0);
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(ReminderMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Màn dựng lại = người dùng vừa thao tác hoặc trạng thái liều vừa đổi.
    _idleSince = _rig.time;
    if (widget.confirmed && !oldWidget.confirmed) _celebrateSince = _rig.time;
    if (_still) _step(0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _rig.dispose();
    _ctl.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _step(dt);
  }

  void _step(double dt) {
    final t = _rig.time + dt;
    final mood = t < _pokeUntil && !widget.confirmed
        ? PetMood.poke
        : reminderPetMood(
            confirmed: widget.confirmed,
            hasError: widget.hasError,
            still: _still,
            time: t,
            idleSeconds: t - _idleSince,
            hourVn: widget.now.toUtc().add(const Duration(hours: 7)).hour,
          );
    _ctl.lookAt(mood == PetMood.point ? const Offset(.5, .9) : Offset.zero);
    _rig
      ..setMood(mood)
      ..tick(dt, ctl: _ctl, still: _still);
  }

  void _onTap() {
    _idleSince = _rig.time;
    _pokeUntil = _rig.time + _pokeSeconds;
    if (_still) _step(0);
  }

  String get _label {
    if (widget.confirmed) return 'Linh vật vui mừng vì bạn đã uống thuốc';
    if (widget.hasError) return 'Linh vật đang lo vì liều chưa được ghi nhận';
    return 'Linh vật nhắc bạn uống thuốc';
  }

  @override
  Widget build(BuildContext context) {
    final vn = widget.scheduledAt.toUtc().add(const Duration(hours: 7));
    return Semantics(
      label: _label,
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            child: ClipRect(
              child: CustomPaint(
                painter: _StagePainter(
                  rig: _rig,
                  hour: vn.hour,
                  minute: vn.minute,
                  confirmed: widget.confirmed,
                  hasError: widget.hasError,
                  still: _still,
                  celebrateAge: () => _rig.time - _celebrateSince,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vẽ sân khấu: sóng lan tỏa phía sau, đồi cỏ, pet chibi và bong bóng đồng hồ.
class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.rig,
    required this.hour,
    required this.minute,
    required this.confirmed,
    required this.hasError,
    required this.still,
    required this.celebrateAge,
  })  : _pet = ChibiPainter(rig),
        super(repaint: rig);

  final ChibiRig rig;
  final ChibiPainter _pet;
  final int hour, minute;
  final bool confirmed, hasError, still;
  final double Function() celebrateAge;

  /// Cạnh khung 100×100 của pet theo dp.
  static const _petBox = 120.0;
  static const _s = _petBox / 100;

  static const _ink = Color(0xFF274280);
  static const _accent = Color(0xFFF59E42);

  @override
  void paint(Canvas canvas, Size size) {
    final feet = Offset(size.width / 2, size.height - ReminderMascot.feetInset);
    final petCenter = feet - const Offset(0, 36 * _s);

    if (!confirmed) _ripples(canvas, petCenter);

    canvas.save();
    canvas.translate(feet.dx - 50 * _s, feet.dy - 96 * _s);
    canvas.scale(_s);
    _pet.paint(canvas);
    canvas.restore();

    if (confirmed) {
      _confetti(canvas, feet - const Offset(0, 70), celebrateAge());
    } else if (!hasError) {
      final bubble = feet + const Offset(62, -128);
      _bubble(canvas, bubble, feet - const Offset(0, 90));
      _clock(canvas, bubble);
    }
  }

  void _ripples(Canvas c, Offset center) {
    const rings = 2;
    for (var i = 0; i < rings; i++) {
      final phase =
          still ? (i + 1) / (rings + 1) : (rig.time * .45 + i / rings) % 1;
      c.drawCircle(
        center,
        48 + phase * 46,
        Paint()..color = Colors.white.withValues(alpha: .16 * (1 - phase)),
      );
    }
  }

  void _bubble(Canvas c, Offset center, Offset head) {
    const r = 21.0;
    final dir = (head - center) / (head - center).distance;
    final side = Offset(-dir.dy, dir.dx);
    final tail = Path()
      ..moveTo(center.dx + side.dx * 7, center.dy + side.dy * 7)
      ..lineTo(center.dx + dir.dx * (r + 10), center.dy + dir.dy * (r + 10))
      ..lineTo(center.dx - side.dx * 7, center.dy - side.dy * 7)
      ..close();
    c.drawCircle(
      center + const Offset(0, 2),
      r,
      Paint()
        ..color = const Color(0xFF0A1430).withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final fill = Paint()..color = Colors.white;
    c.drawPath(tail, fill);
    c.drawCircle(center, r, fill);
  }

  /// Đồng hồ báo thức chỉ đúng giờ dự kiến, rung nhẹ như đang reo.
  void _clock(Canvas c, Offset p) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    c.save();
    c.translate(p.dx, p.dy);
    if (!still) c.rotate(math.sin(rig.time * 28) * .08 * _ringing);
    c.drawCircle(const Offset(-8, -11), 3, Paint()..color = _accent);
    c.drawCircle(const Offset(8, -11), 3, Paint()..color = _accent);
    c.drawCircle(Offset.zero, 12, Paint()..color = Colors.white);
    c.drawCircle(Offset.zero, 12, ink);
    final m = minute / 60 * 2 * math.pi;
    final h = (hour % 12 + minute / 60) / 12 * 2 * math.pi;
    c.drawLine(Offset.zero, Offset(math.sin(h), -math.cos(h)) * 6, ink);
    c.drawLine(Offset.zero, Offset(math.sin(m), -math.cos(m)) * 9, ink);
    c.restore();
  }

  /// Reo 0.6 giây trong mỗi chu kỳ 2 giây.
  double get _ringing => (rig.time % 2) < .6 ? 1 : 0;

  static const _confettiColors = [
    Color(0xFFFF5D7A),
    Color(0xFFFFC928),
    Color(0xFF1B9AFC),
    Color(0xFFFFFFFF),
    Color(0xFF8B5CF6),
  ];

  void _confetti(Canvas c, Offset o, double age) {
    final a = still ? .5 : age % _confettiPeriod;
    final r = math.Random(11);
    for (var i = 0; i < 26; i++) {
      final ang = -math.pi / 2 + (r.nextDouble() - .5) * math.pi * 1.3;
      final speed = 110 + r.nextDouble() * 120;
      final p = o +
          Offset(math.cos(ang) * speed * a,
              math.sin(ang) * speed * a + 240 * a * a);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a * (4 + i % 5));
      c.drawRect(
        const Rect.fromLTWH(-3, -1.5, 6, 3),
        Paint()
          ..color = _confettiColors[i % _confettiColors.length]
              .withValues(alpha: (1 - a / _confettiPeriod).clamp(0.0, 1.0)),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.confirmed != confirmed ||
      old.hasError != hasError ||
      old.still != still ||
      old.hour != hour ||
      old.minute != minute;
}
