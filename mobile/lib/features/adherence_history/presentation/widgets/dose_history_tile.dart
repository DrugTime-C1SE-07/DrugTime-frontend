import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/adherence_history.dart';
import '../utils/adherence_history_format.dart';
import '../utils/reminder_palette.dart';
import 'dose_timeline_rail.dart';
import 'history_motion.dart';

class DoseHistoryTile extends StatelessWidget {
  const DoseHistoryTile(
      {super.key,
      required this.dose,
      this.showDate = false,
      this.upcoming = false,
      this.locallyConfirmed = false,
      this.prototypeStyle = false,
      this.details,
      this.countdownMinutes,
      this.onTap});
  final HistoryDose dose;
  final bool showDate;
  final bool upcoming;
  final bool locallyConfirmed;
  final bool prototypeStyle;
  final String? details;

  /// Minutes left before an upcoming dose (day tab only, under 60): badge reads "Còn N phút".
  final int? countdownMinutes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = upcoming && !locallyConfirmed;
    final status = locallyConfirmed ? HistoryDoseStatus.taken : dose.status;
    final interactive =
        onTap != null && (status != HistoryDoseStatus.pending || isUpcoming);
    final (color, background, icon) = isUpcoming
        ? (ReminderPalette.teal, ReminderPalette.surfaceTint, Icons.schedule)
        : switch (status) {
            HistoryDoseStatus.taken => (
                ReminderPalette.success,
                ReminderPalette.successBackground,
                Icons.check_circle_outline
              ),
            HistoryDoseStatus.late => (
                AppColors.cautionText,
                AppColors.cautionBg,
                Icons.schedule
              ),
            HistoryDoseStatus.missed => (
                ReminderPalette.missed,
                ReminderPalette.missedBackground,
                Icons.error_outline
              ),
            HistoryDoseStatus.pending => (
                AppColors.inkMuted,
                AppColors.surfaceMuted,
                Icons.hourglass_empty
              ),
            HistoryDoseStatus.unverified => (
                AppColors.inkMuted,
                AppColors.surfaceMuted,
                Icons.cloud_off_outlined
              ),
          };
    final countdown = prototypeStyle && isUpcoming ? countdownMinutes : null;
    final badge = countdown != null
        ? 'Còn ${countdown < 1 ? 1 : countdown} phút'
        : isUpcoming
            ? 'Sắp tới'
            : HistoryFormat.status(status);
    final clock = HistoryFormat.time(dose.scheduledAt);
    final Widget state = prototypeStyle
        ? _AnimatedStatusBadge(
            label: badge,
            status: isUpcoming ? null : status,
            color: color,
            background: background,
            icon: isUpcoming ? Icons.schedule : icon,
          )
        : _badgeBox(
            color: color,
            background: background,
            label: badge,
            iconWidget: Icon(isUpcoming ? Icons.schedule : icon,
                size: 16, color: color));
    final name =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(dose.medicationName, style: AppTextStyles.bodyStrong),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Flexible(
              child: Text(
            showDate
                ? '${HistoryFormat.shortDay(HistoryFormat.today(dose.scheduledAt), reference: HistoryFormat.today(dose.scheduledAt))} · $clock'
                : clock,
            style:
                AppTextStyles.captionStrong.copyWith(color: AppColors.inkMuted),
          )),
        ]),
      ),
    ]);
    final missed = status == HistoryDoseStatus.missed;
    final rail = missed && !prototypeStyle ? ReminderPalette.missed : null;
    final cardColor =
        missed && prototypeStyle ? const Color(0xFFFFF4F2) : AppColors.surface;
    return Semantics(
      container: true,
      button: interactive,
      onTap: interactive ? onTap : null,
      label:
          '${dose.medicationName}, ${isUpcoming ? 'Sắp tới' : status.label}${countdown != null ? ', còn ${countdown < 1 ? 1 : countdown} phút' : ''}, giờ dự kiến ${HistoryFormat.time(dose.scheduledAt)}, ${showDate ? HistoryFormat.day(HistoryFormat.today(dose.scheduledAt)) : ''}, ${locallyConfirmed ? 'Đã xác nhận tại Trang chủ' : HistoryFormat.actual(dose)}',
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(16) > 20;
          final card = Material(
            color: rail ?? cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              side: missed && prototypeStyle
                  ? const BorderSide(color: ReminderPalette.missedBackground)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.only(left: rail == null ? 0 : 4),
              child: Material(
                color: cardColor,
                child: InkWell(
                  onTap: interactive ? onTap : null,
                  child: Padding(
                    padding: prototypeStyle
                        // Same metrics as the Home dose card so both tabs read alike.
                        ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
                        : const EdgeInsets.all(14),
                    child: prototypeStyle
                        ? _prototypeRow(
                            clock: clock,
                            state: state,
                            statusColor: color,
                          )
                        : Row(
                            children: [
                              const PillTile(colored: true),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: compact
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              name,
                                              const SizedBox(height: 8),
                                              state
                                            ])
                                      : name),
                              if (!compact) ...[
                                const SizedBox(width: 8),
                                state,
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
          // Only the day tab's rows fly into the detail page; "Theo thuốc" rows reuse this
          // widget and must not share hero tags with them.
          final hero = prototypeStyle && onTap != null
              ? HeroMode(
                  enabled: HistoryMotion.enabled(context),
                  child: Hero(
                      tag: DoseHeroTag(dose.scheduleId, dose.scheduledAt),
                      child: card))
              : card;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: hero,
          );
        }),
      ),
    );
  }

  Widget _prototypeRow({
    required String clock,
    required Widget state,
    required Color statusColor,
  }) {
    final info = details?.trim() ?? '';
    return Row(
      children: [
        const PillTile(colored: true, size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(clock,
                  style: AppTextStyles.captionStrong.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
              Text(dose.medicationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
              if (info.isNotEmpty)
                Text(info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: state,
        ),
      ],
    );
  }
}

Widget _badgeBox({
  required Color color,
  required Color background,
  required String label,
  required Widget iconWidget,
  Key? key,
}) =>
    Container(
      key: key,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        iconWidget,
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: AppTextStyles.captionStrong.copyWith(color: color))),
      ]),
    );

/// Status badge of a day-tab row. A new label scales and fades in over the old one; when the
/// dose turns "Đã uống" while the row is on screen, the check mark draws itself once.
class _AnimatedStatusBadge extends StatefulWidget {
  const _AnimatedStatusBadge({
    required this.label,
    required this.status,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;

  /// `null` while the dose is upcoming.
  final HistoryDoseStatus? status;
  final Color color, background;
  final IconData icon;

  @override
  State<_AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<_AnimatedStatusBadge> {
  final _check = GlobalKey<State<DrawnCheck>>();

  @override
  void didUpdateWidget(_AnimatedStatusBadge old) {
    super.didUpdateWidget(old);
    if (old.status != HistoryDoseStatus.taken &&
        widget.status == HistoryDoseStatus.taken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check.replay();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taken = widget.status == HistoryDoseStatus.taken;
    final box = _badgeBox(
      key: ValueKey(('dose-badge', widget.label, widget.status)),
      color: widget.color,
      background: widget.background,
      label: widget.label,
      iconWidget: taken
          ? DrawnCheck(key: _check, color: widget.color)
          : Icon(widget.icon, size: 16, color: widget.color),
    );
    final animate = HistoryMotion.enabled(context);
    return AnimatedSwitcher(
      duration: animate ? HistoryMotion.selection : Duration.zero,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerRight,
          children: [...previous, if (current != null) current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
            scale: Tween(begin: .92, end: 1.0).animate(animation),
            child: child),
      ),
      child: box,
    );
  }
}
