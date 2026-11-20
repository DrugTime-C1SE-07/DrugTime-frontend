import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/storage/local_db/local_models.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import '../widgets/dose_history_tile.dart';
import '../widgets/history_week_selector.dart';
import '../widgets/history_motion.dart';
import '../widgets/history_feedback.dart';
import '../widgets/history_summary.dart';
import '../../../../core/preview/app_preview_scope.dart';
import '../widgets/history_info_sheet.dart';
import '../widgets/reminder_day_overview.dart';
import '../widgets/reminder_scene_header.dart';
import '../utils/reminder_palette.dart';
import 'adherence_month_screen.dart';
import 'medication_history_screen.dart';
import '../../../home/presentation/home_schedule_controller.dart';

class AdherenceHistoryScreen extends StatefulWidget {
  const AdherenceHistoryScreen({super.key, this.active = true, this.onRetry});
  final bool active;
  final Future<void> Function()? onRetry;

  @override
  State<AdherenceHistoryScreen> createState() => _AdherenceHistoryScreenState();
}

class _AdherenceHistoryScreenState extends State<AdherenceHistoryScreen>
    with WidgetsBindingObserver {
  AdherenceHistoryController? _controller;
  HomeScheduleController? _homeController;
  int? _seenHomeAccessRevision;
  int _seenConfirmedSeq = 0;
  Route<void>? _detailRoute;
  int? _detailAccessRevision;
  bool _closing = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _queueLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AdherenceHistoryScope.read(context);
    if (_controller != controller) {
      _controller?.removeListener(_changed);
      _controller = controller..addListener(_changed);
    }
    final home = HomeScheduleScope.maybeOf(context);
    if (_homeController != home) {
      _homeController?.removeListener(_homeChanged);
      if (_homeController != null) {
        _controller?.clearHomeConfirmation(notify: false);
      }
      _homeController = home;
      _seenHomeAccessRevision = home?.accessRevision;
      _seenConfirmedSeq = home?.confirmedSeq ?? 0;
      home?.addListener(_homeChanged);
    }
  }

  void _homeChanged() {
    final home = _homeController;
    final controller = _controller;
    if (!mounted || home == null || controller == null) return;
    final accessRevision = home.accessRevision;
    if (_seenHomeAccessRevision != accessRevision) {
      _seenHomeAccessRevision = accessRevision;
      _seenConfirmedSeq = home.confirmedSeq;
      controller.clearHomeConfirmation();
      return;
    }
    if (home.confirmedSeq <= _seenConfirmedSeq) return;
    _seenConfirmedSeq = home.confirmedSeq;
    final occurrence = home.lastConfirmed;
    if (occurrence != null) {
      controller.projectHomeConfirmation(occurrence, accessRevision);
    }
  }

  void _queueLoad() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) unawaited(_controller!.load());
      });

  void _changed() {
    if (_detailRoute != null &&
        (_detailAccessRevision != _controller!.accessRevision ||
            _controller!.error?.removesAccess == true)) {
      _closeDetail();
    }
  }

  void _closeDetail() {
    final route = _detailRoute;
    if (route == null || _closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (route.isActive && navigator != null && navigator.mounted) {
        navigator.removeRoute(route);
      }
      if (_detailRoute == route) _detailRoute = null;
      _closing = false;
    });
  }

  @override
  void didUpdateWidget(AdherenceHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _queueLoad();
    if (!widget.active && oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.active) _controller!.deactivate();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.active) return;
    if (state == AppLifecycleState.resumed) _queueLoad();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller!.deactivate();
    }
  }

  Future<void> _openPage({bool medication = false, HistoryDose? dose}) async {
    final c = _controller!;
    if (!widget.active ||
        _opening ||
        _detailRoute != null ||
        c.error?.removesAccess == true) {
      return;
    }
    _opening = true;
    final revision = c.accessRevision;
    final asOf = c.history?.asOf;
    final route = HistoryPageRoute<void>(
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      settings: RouteSettings(
          name: dose != null
              ? 'adherence-dose'
              : medication
                  ? 'adherence-medication'
                  : 'adherence-month'),
      builder: (_) => dose != null
          ? DoseDetailScreen(dose: dose, asOf: asOf!)
          : medication
              ? MedicationHistoryScreen(onRetry: widget.onRetry)
              : AdherenceMonthScreen(onRetry: widget.onRetry),
    );
    _detailRoute = route;
    _detailAccessRevision = revision;
    unawaited(
        c.changeMode(medication ? HistoryMode.medication : HistoryMode.date));
    try {
      await Navigator.of(context).push(route);
    } finally {
      if (_detailRoute == route) _detailRoute = null;
      _opening = false;
      if (mounted &&
          widget.active &&
          c.accessRevision == revision &&
          c.error?.removesAccess != true &&
          c.mode != HistoryMode.date) {
        await c.changeMode(HistoryMode.date);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);
    _homeController?.removeListener(_homeChanged);
    _closeDetail();
    super.dispose();
  }

  String _timeSection(DateTime scheduledAt) {
    final hour = scheduledAt.toUtc().add(const Duration(hours: 7)).hour;
    return switch (hour) {
      < 11 => 'BUỔI SÁNG',
      < 14 => 'BUỔI TRƯA',
      < 18 => 'BUỔI CHIỀU',
      _ => 'BUỔI TỐI',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AdherenceHistoryScope.of(context);
    final group = c.selectedGroup;
    final doses = List<HistoryDose>.of(group?.doses ?? const [])
      ..sort((a, b) {
        final order = a.scheduledAt.compareTo(b.scheduledAt);
        return order != 0 ? order : a.scheduleId.compareTo(b.scheduleId);
      });
    final sections = <String, List<HistoryDose>>{};
    for (final dose in doses) {
      (sections[_timeSection(dose.scheduledAt)] ??= []).add(dose);
    }
    final blocked = c.error?.removesAccess == true;
    final asOf = c.history?.asOf;
    final preview = AppPreviewScope.maybeOf(context);
    final now = preview?.clock ?? c.history?.asOf ?? DateTime.now();
    final weekday = switch (c.selectedDay.weekday) {
      1 => 'Thứ Hai',
      2 => 'Thứ Ba',
      3 => 'Thứ Tư',
      4 => 'Thứ Năm',
      5 => 'Thứ Sáu',
      6 => 'Thứ Bảy',
      _ => 'Chủ nhật',
    };
    final dateLabel =
        '$weekday, ${HistoryFormat.shortDay(c.selectedDay, reference: c.today)}';
    return HistoryMotionScope(
      active: widget.active,
      child: ColoredBox(
        color: ReminderPalette.canvas,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ReminderSceneHeader(
                  title: 'Lịch nhắc',
                  subtitle: dateLabel,
                  now: now,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (preview != null) const AppPreviewBadge(),
                    const HistoryInfoButton(),
                    IconButton(
                      tooltip: 'Mở lịch tháng',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: ReminderPalette.surface,
                        shape: const CircleBorder(),
                      ),
                      onPressed: blocked ? null : () => unawaited(_openPage()),
                      icon: const Icon(Icons.calendar_month_outlined,
                          color: ReminderPalette.teal),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn lịch sử',
                      enabled: !blocked,
                      icon: const Icon(Icons.more_horiz,
                          color: ReminderPalette.teal),
                      onSelected: (_) => unawaited(_openPage(medication: true)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'medication', child: Text('Theo thuốc'))
                      ],
                    ),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      HistoryWeekSelector(controller: c),
                      const SizedBox(height: 8),
                      if (c.loading || c.error != null)
                        HistoryLoadState(controller: c, onRetry: widget.onRetry)
                      else if (c.history?.mode == HistoryMode.date) ...[
                        HistoryEntrance(
                          key: ValueKey((c, c.contentRevision, 'overview')),
                          child: ReminderDayOverview(
                              day: c.selectedDay, today: c.today, group: group),
                        ),
                        const SizedBox(height: 10),
                        if (doses.isEmpty) const HistoryEmpty(),
                        for (final section in sections.entries)
                          HistoryEntrance(
                            key: ValueKey((c, c.contentRevision, section.key)),
                            child: Container(
                              key: ValueKey(section.key),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ReminderPeriodHeader(
                                    title: section.key,
                                    doses: section.value,
                                    isConfirmed: c.isHomeConfirmed,
                                  ),
                                  const SizedBox(height: 6),
                                  for (final dose in section.value)
                                    DoseHistoryTile(
                                      key: ValueKey(
                                          (dose.scheduleId, dose.scheduledAt)),
                                      dose: dose,
                                      prototypeStyle: true,
                                      details: _scheduleDetails(
                                          c.scheduleById(dose.scheduleId)),
                                      locallyConfirmed: c.isHomeConfirmed(dose),
                                      onTap: () =>
                                          unawaited(_openPage(dose: dose)),
                                      upcoming: !c.isHomeConfirmed(dose) &&
                                          dose.status ==
                                              HistoryDoseStatus.pending &&
                                          asOf != null &&
                                          dose.scheduledAt.isAfter(asOf),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _scheduleDetails(LocalMedicationSchedule? schedule) {
    if (schedule == null) return null;
    final strength = schedule.strengthText?.trim();
    final quantity = schedule.quantityPerDose.trim();
    final parts = [
      if (strength != null && strength.isNotEmpty) strength,
      if (quantity.isNotEmpty) quantity,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _ReminderPeriodHeader extends StatelessWidget {
  const _ReminderPeriodHeader({
    required this.title,
    required this.doses,
    required this.isConfirmed,
  });

  final String title;
  final List<HistoryDose> doses;
  final bool Function(HistoryDose) isConfirmed;

  @override
  Widget build(BuildContext context) {
    final palette = ReminderPalette.period(title);
    final completed = doses
        .where((dose) =>
            isConfirmed(dose) ||
            dose.status == HistoryDoseStatus.taken ||
            dose.status == HistoryDoseStatus.late)
        .length;
    final label = title.toLowerCase().replaceFirst('buổi ', 'Buổi ');
    return Container(
      key: ValueKey('period-$title'),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(palette.icon, size: 16, color: palette.foreground),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: AppTextStyles.captionStrong
                  .copyWith(color: palette.foreground, fontSize: 13)),
        ),
        Text('$completed/${doses.length}',
            style: AppTextStyles.captionStrong
                .copyWith(color: palette.foreground, fontSize: 12)),
      ]),
    );
  }
}
