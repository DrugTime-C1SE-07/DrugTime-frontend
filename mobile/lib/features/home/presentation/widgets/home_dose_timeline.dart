import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../adherence_history/domain/entities/adherence_history.dart';
import '../../../adherence_history/presentation/utils/adherence_history_format.dart';
import '../home_schedule_controller.dart';

const _green = Color(0xFF16A052);
const _red = Color(0xFFE52429);

/// "Lịch hôm nay" trên trang chủ theo Figma S05: dòng liều, thẻ liều kế tiếp,
/// thẻ bỏ lỡ pulse một lần, chuỗi chuyển cảnh sau khi xác nhận.
class HomeDoseTimeline extends StatefulWidget {
  const HomeDoseTimeline({
    super.key,
    required this.controller,
    required this.now,
    required this.onAdd,
    required this.onScan,
  });

  final HomeScheduleController controller;
  final DateTime now;
  final VoidCallback onAdd, onScan;

  /// Thời gian thẻ vừa xác nhận giữ trạng thái "Đã uống lúc hh:mm" trước khi thu gọn.
  static const celebrateHold = Duration(milliseconds: 1600);

  /// Các liều bỏ lỡ đã pulse trong phiên app này (mỗi liều chỉ pulse một lần).
  static final pulsed = <(int, DateTime)>{};

  @override
  State<HomeDoseTimeline> createState() => _HomeDoseTimelineState();
}

class _HomeDoseTimelineState extends State<HomeDoseTimeline> {
  late int _seenSeq;
  (int, DateTime)? _justConfirmed;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _seenSeq = widget.controller.confirmedSeq;
  }

  @override
  void didUpdateWidget(HomeDoseTimeline old) {
    super.didUpdateWidget(old);
    final c = widget.controller;
    if (c.confirmedSeq != _seenSeq) {
      _seenSeq = c.confirmedSeq;
      _justConfirmed = c.lastConfirmed;
      _hold?.cancel();
      _hold = Timer(HomeDoseTimeline.celebrateHold, () {
        if (mounted) setState(() => _justConfirmed = null);
      });
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  static (int, DateTime) _key(HistoryDose d) =>
      (d.scheduleId, d.scheduledAt.toUtc());

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final now = widget.now;
    if (controller.failed) {
      return Card(
          child: ListTile(
              title: const Text('Không tải được lịch hôm nay'),
              trailing: TextButton(
                  onPressed: controller.load, child: const Text('Thử lại'))));
    }
    final doses = controller.day?.doses ?? const <HistoryDose>[];
    if (doses.isEmpty) {
      return _EmptySchedule(onAdd: widget.onAdd, onScan: widget.onScan);
    }
    final next = doses
        .where((dose) =>
            HomeScheduleController.canConfirm(dose, now) ||
            (dose.status == HistoryDoseStatus.pending &&
                dose.scheduledAt.isAfter(now)))
        .firstOrNull;
    final celebrating = _justConfirmed == null
        ? null
        : doses.where((d) => _key(d) == _justConfirmed).firstOrNull;
    // trong lúc thẻ vừa uống còn mở, liều kế tiếp chờ tới lượt
    final expanded = celebrating ?? next;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (controller.message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(controller.message!, semanticsLabel: controller.message),
        ),
      for (final dose in doses)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
                width: 28,
                child: Stack(alignment: Alignment.topCenter, children: [
                  Container(width: 2, color: const Color(0xFFE0E5E2)),
                  Padding(
                      padding: EdgeInsets.only(top: dose == expanded ? 23 : 15),
                      child: DoseTimelineMarker(
                          dose: dose,
                          next: dose == expanded && dose != celebrating)),
                ])),
            Expanded(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: dose == expanded
                    ? _NextDoseCard(
                        key: ValueKey(('next', _key(dose))),
                        dose: dose,
                        now: now,
                        controller: controller,
                        celebrating: dose == celebrating,
                      )
                    : _DoseRow(key: ValueKey(('row', _key(dose))), dose: dose),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// Nhãn phía trên giờ của thẻ liều kế tiếp.
String nextDoseLabel(HistoryDose dose, DateTime now) {
  final minutes = dose.scheduledAt.difference(now).inMinutes;
  if (minutes <= 0) return 'Liều tiếp theo · Đến giờ rồi';
  if (minutes < 60) return 'Liều tiếp theo · $minutes phút nữa';
  final hour = HistoryFormat.vietnam(dose.scheduledAt).hour;
  if (hour >= 18) return 'Liều tiếp theo · Tối nay';
  final h = minutes ~/ 60, m = minutes % 60;
  return 'Liều tiếp theo · $h giờ${m == 0 ? '' : ' $m phút'} nữa';
}

class _NextDoseCard extends StatelessWidget {
  const _NextDoseCard({
    super.key,
    required this.dose,
    required this.now,
    required this.controller,
    required this.celebrating,
  });
  final HistoryDose dose;
  final DateTime now;
  final HomeScheduleController controller;
  final bool celebrating;

  @override
  Widget build(BuildContext context) {
    final late = dose.status == HistoryDoseStatus.late;
    final takenAt = dose.takenAt ?? now;
    final pending = controller.isPending(dose);
    final enabled = !celebrating &&
        !controller.saving &&
        !pending &&
        HomeScheduleController.canConfirm(dose, now);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFFE5F3EF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const DoseIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        celebrating
                            ? (late
                                ? 'Đã ghi nhận · uống trễ'
                                : 'Tuyệt vời · đúng giờ')
                            : nextDoseLabel(dose, now),
                        style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600)),
                    Text(HistoryFormat.time(dose.scheduledAt),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(dose.medicationName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          PressScale(
            enabled: enabled,
            child: FilledButton.icon(
              style: celebrating
                  ? FilledButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _green,
                      disabledForegroundColor: Colors.white,
                    )
                  : null,
              onPressed: enabled ? () => controller.confirm(dose) : null,
              icon: const Icon(LucideIcons.check),
              label: Text(celebrating
                  ? 'Đã uống lúc ${HistoryFormat.time(takenAt)}'
                  : pending
                      ? 'Đang chờ đồng bộ'
                      : controller.saving
                          ? 'Đang ghi nhận…'
                          : 'Đã uống'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Thu nhỏ nhẹ khi nhấn (phản hồi nhấn theo Figma "Nhấn Đã uống").
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: widget.enabled ? (_) => _set(true) : null,
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      );
}

class _DoseRow extends StatefulWidget {
  const _DoseRow({super.key, required this.dose});
  final HistoryDose dose;

  @override
  State<_DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends State<_DoseRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    final d = widget.dose;
    final key = (d.scheduleId, d.scheduledAt.toUtc());
    if (d.status == HistoryDoseStatus.missed &&
        HomeDoseTimeline.pulsed.add(key)) {
      _pulse = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dose;
    final missed = d.status == HistoryDoseStatus.missed;
    final row = Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: missed
              ? const BorderSide(color: Color(0xFFF6C9CB))
              : const BorderSide(color: Color(0xFFE9EDEB))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(children: [
          DoseIcon(muted: missed),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  missed
                      ? '${HistoryFormat.time(d.scheduledAt)} · Bỏ lỡ'
                      : HistoryFormat.time(d.scheduledAt),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: missed
                          ? Colors.red.shade700
                          : const Color(0xFF5B6661))),
              Text(d.medicationName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (_badge(d.status) case final badge?) badge,
        ]),
      ),
    );
    final pulse = _pulse;
    if (pulse == null) return row;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final v = math.sin(pulse.value * math.pi);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _red.withValues(alpha: .28 * v),
                  blurRadius: 14 * v,
                  spreadRadius: 3 * v),
            ],
          ),
          child: Transform.scale(scale: 1 + .015 * v, child: child),
        );
      },
      child: row,
    );
  }

  Widget? _badge(HistoryDoseStatus s) {
    final (String, Color, Color)? style = switch (s) {
      HistoryDoseStatus.taken => ('Đã uống', _green, const Color(0xFFE6F4EA)),
      HistoryDoseStatus.late => (
          'Uống trễ',
          const Color(0xFFB26A00),
          const Color(0xFFFFF1DC)
        ),
      HistoryDoseStatus.unverified => (
          s.label,
          const Color(0xFF5B6661),
          const Color(0xFFEEF1EF)
        ),
      _ => null,
    };
    if (style == null) return null;
    final (label, color, bg) = style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.circleCheck, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Ô vuông chứa viên thuốc (cam/trắng) dùng trong dòng liều.
class DoseIcon extends StatelessWidget {
  const DoseIcon({super.key, this.muted = false});
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: muted ? const Color(0xFFE6F3EF) : const Color(0xFFFFF0DF),
            borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Transform.rotate(
            angle: -math.pi / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 26,
                height: 12,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: muted
                                      ? const Color(0xFF8FC9B5)
                                      : const Color(0xFFF59E42)))),
                      const Expanded(
                          child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white))),
                    ]),
              ),
            ),
          ),
        ),
      );
}

class DoseTimelineMarker extends StatelessWidget {
  const DoseTimelineMarker({super.key, required this.dose, required this.next});

  final HistoryDose dose;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final missed = dose.status == HistoryDoseStatus.missed;
    final taken = dose.status == HistoryDoseStatus.taken ||
        dose.status == HistoryDoseStatus.late;
    return Container(
      width: missed ? 20 : 24,
      height: missed ? 20 : 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: missed
            ? _red
            : next
                ? AppColors.brand
                : taken
                    ? const Color(0xFFF0FAF2)
                    : const Color(0xFFF6F7F5),
        border: missed
            ? null
            : Border.all(
                color: next
                    ? const Color(0xFFB3DDD4)
                    : taken
                        ? _green
                        : const Color(0xFFCCD8D3),
                width: next ? 2.5 : 2),
      ),
      child: missed
          ? const Icon(Icons.priority_high, size: 12, color: Colors.white)
          : taken
              ? const Icon(LucideIcons.check, size: 13, color: _green)
              : next
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: SizedBox.square(dimension: 6))
                  : null,
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.onAdd, required this.onScan});
  final VoidCallback onAdd, onScan;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(
                child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFE6F3EF),
                    child: DoseIcon())),
            const SizedBox(height: 12),
            const Text('Chưa có lịch uống thuốc',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
                'Thêm thuốc đầu tiên để DrugTime nhắc bạn đúng giờ mỗi ngày.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAdd, child: const Text('Thêm thuốc')),
            OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(LucideIcons.scanLine),
                label: const Text('Quét vỏ hộp')),
          ]),
        ),
      );
}
