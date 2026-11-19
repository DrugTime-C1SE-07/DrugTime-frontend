import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../adherence/domain/entities/adherence_history.dart';
import '../../../patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import '../../domain/monitor_digest.dart';
import '../../domain/monitor_models.dart';
import 'monitor_palette.dart';

/// Card trạng thái trên màn "Hôm nay" (R2b–R2d). Trạng thái ổn (R2a) không có card.
///
/// Người thân chỉ xem (QD-27): hành động duy nhất là gửi lời nhắc tới máy người bệnh.
class CareStatusCard extends StatelessWidget {
  const CareStatusCard({
    super.key,
    required this.mood,
    required this.name,
    required this.now,
    this.dose,
    this.receipt,
    this.wait = Duration.zero,
    this.busy = false,
    this.message,
    this.onNudge,
  });

  final CareMood mood;
  final String name;
  final DateTime now;

  /// Liều cần chú ý (missed / nudged) hoặc liều vừa uống bù (recovered).
  final AdherenceDose? dose;
  final ReminderReceipt? receipt;
  final Duration wait;
  final bool busy;
  final String? message;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .08), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final dose = this.dose;
    if (dose == null || mood == CareMood.ok) {
      return const SizedBox(key: ValueKey('care-none'), width: double.infinity);
    }
    final time = monitorTime(dose.scheduledAt);
    switch (mood) {
      case CareMood.missed:
      case CareMood.overdue:
        final late = now.difference(dose.scheduledAt);
        final missed = mood == CareMood.missed;
        final lateText = late.isNegative
            ? 'Liều $time'
            : 'Liều $time · ${missed ? 'đã trễ' : 'quá giờ'} ${formatDelay(late)}';
        return _card(
          key: ValueKey(missed ? 'care-missed' : 'care-overdue'),
          bg: missed ? MonitorColors.missedTint : MonitorColors.lateTint,
          fg: missed ? const Color(0xFF9B1C1C) : const Color(0xFF8A4B0F),
          icon: missed ? Icons.warning_amber_rounded : Icons.help_outline,
          // Chỉ `bo_lo` (server xác minh) mới được nói "chưa uống" (QD-24/25).
          title: missed
              ? '$name chưa uống ${dose.medicationName}'
              : '$name chưa xác nhận ${dose.medicationName}',
          body: missed
              ? lateText
              : '$lateText\nCó thể đã uống nhưng điện thoại chưa đồng bộ.',
          action: FilledButton.icon(
            key: const Key('nudge-button'),
            onPressed: busy || wait > Duration.zero ? null : onNudge,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(busy ? 'Đang gửi…' : 'Nhắc $name'),
            style: FilledButton.styleFrom(
                backgroundColor:
                    missed ? const Color(0xFFB91C1C) : const Color(0xFFB4561E),
                minimumSize: const Size.fromHeight(48)),
          ),
        );
      case CareMood.nudged:
        final r = receipt;
        final ago = r == null ? null : now.difference(r.requestedAt);
        return _card(
          key: const ValueKey('care-nudged'),
          bg: MonitorColors.nudgedTint,
          fg: MonitorColors.nudged,
          icon: Icons.notifications_none_rounded,
          title: r == null
              ? 'Đã nhắc $name'
              : 'Đã nhắc $name lúc ${monitorTime(r.requestedAt)}',
          body: 'Đang chờ $name bấm "Đã uống" cho liều $time',
          action: FilledButton.tonalIcon(
            key: const Key('nudge-button'),
            onPressed: busy || wait > Duration.zero ? null : onNudge,
            icon: const Icon(Icons.schedule),
            label: Text(wait > Duration.zero
                ? 'Nhắc lại sau ${_countdown(wait)}'
                : ago == null
                    ? 'Nhắc lại'
                    : 'Đã nhắc · ${formatDelay(ago)} trước · Nhắc lại'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        );
      case CareMood.recovered:
        final taken = dose.takenAt!;
        return _card(
          key: const ValueKey('care-recovered'),
          bg: MonitorColors.takenTint,
          fg: MonitorColors.taken,
          icon: Icons.check_circle_outline,
          title:
              '$name đã uống ${dose.medicationName} lúc ${monitorTime(taken)}',
          body: [
            if (receipt != null) 'Sau lời nhắc của bạn',
            'trễ ${formatDelay(taken.difference(dose.scheduledAt))}',
          ].join(' · '),
        );
      case CareMood.ok:
        return const SizedBox.shrink();
    }
  }

  static String _countdown(Duration d) {
    final s = d.inSeconds + 1;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _card({
    required Key key,
    required Color bg,
    required Color fg,
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.heading.copyWith(color: fg)),
              const SizedBox(height: 2),
              Text(body, style: AppTextStyles.body.copyWith(color: fg)),
            ]),
          ),
        ]),
        if (action != null) ...[const SizedBox(height: 12), action],
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!,
              key: const Key('nudge-message'),
              style: AppTextStyles.caption.copyWith(color: fg)),
        ],
        if (action != null) ...[
          const SizedBox(height: 6),
          Text(
              'Lời nhắc không phải hướng dẫn uống bù. Đã gửi không đồng nghĩa người bệnh đã đọc.',
              style: AppTextStyles.caption.copyWith(color: fg)),
        ],
      ]),
    );
  }
}
