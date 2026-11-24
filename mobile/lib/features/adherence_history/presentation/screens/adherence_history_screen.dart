import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/storage/local_db/local_models.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import '../widgets/dose_history_tile.dart';
import '../widgets/dose_timeline_rail.dart';
import '../widgets/history_week_selector.dart';
import '../widgets/history_motion.dart';
import '../widgets/history_feedback.dart';
import '../widgets/history_summary.dart';
import '../../../../core/preview/app_preview_scope.dart';
import 'dose_detail_screen.dart';
import '../widgets/reminder_day_overview.dart';
import '../widgets/reminder_scene_header.dart';
import '../utils/reminder_palette.dart';
import 'adherence_month_screen.dart';
import 'medication_history_screen.dart';
import '../../../home/presentation/home_schedule_controller.dart';

class AdherenceHistoryScreen extends StatefulWidget {
  const AdherenceHistoryScreen(
      {super.key, this.active = true, this.onRetry, this.clock});
  final bool active;
  final Future<void> Function()? onRetry;

  /// Wall clock for the "Bây giờ" line and countdowns; tests inject a fixed time.
  final DateTime Function()? clock;

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

  /// Ticks on every minute boundary while the tab is active and the app is in front.
  Timer? _minuteTick;
  AppLifecycleState? _lifecycle = WidgetsBinding.instance.lifecycleState;

  /// Direction of the last day change: +1 later day, -1 earlier day, 0 none yet.
  DateTime? _shownDay;
  int _dayDirection = 0;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _queueLoad();
    _scheduleTick();
  }

  DateTime _now() =>
      widget.clock?.call() ??
      AppPreviewScope.maybeOf(context)?.clock ??
      DateTime.now();

  bool get _ticking =>
      widget.active &&
      (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);

  void _scheduleTick() {
    _minuteTick?.cancel();
    _minuteTick = null;
    if (!_ticking) return;
    final ms = DateTime.now().millisecondsSinceEpoch;
    _minuteTick = Timer(Duration(milliseconds: 60000 - ms % 60000), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
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
    if (widget.active != oldWidget.active) _scheduleTick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _scheduleTick();
    if (!widget.active) return;
    if (state == AppLifecycleState.resumed) {
      _queueLoad();
      setState(() {});
    }
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

  /// Swipe on the dose list: left → next day, right → previous day. `selectDay` ignores
  /// future days, so a left swipe on today changes nothing (and does not buzz).
  void _swipeDay(DragEndDetails details) {
    final c = _controller!;
    final velocity = details.primaryVelocity ?? 0;
    final distance = _drag;
    _drag = 0;
    final slow = velocity.abs() <= HistoryMotion.swipeVelocity;
    final int step;
    if (velocity < -HistoryMotion.swipeVelocity ||
        (slow && distance < -HistoryMotion.swipeDistance)) {
      step = 1;
    } else if (velocity > HistoryMotion.swipeVelocity ||
        (slow && distance > HistoryMotion.swipeDistance)) {
      step = -1;
    } else {
      return;
    }
    final before = c.selectedDay;
    final target = DateTime.utc(before.year, before.month, before.day + step);
    if (target.isAfter(c.today) || c.error?.removesAccess == true) return;
    unawaited(c.selectDay(target).then((_) {
      if (c.selectedDay != before) unawaited(HapticFeedback.selectionClick());
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteTick?.cancel();
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

  /// Dumi's pose for today's progress: all taken → happy, any missed → thinking, else hello.
  String _todayMascot(AdherenceHistoryController c) {
    final summary = c.dayGroup(c.today)?.summary;
    if (summary == null) return AppAssets.mascotHello;
    if (summary.missed > 0) return AppAssets.mascotThinking;
    if (summary.total > 0 && summary.pending == 0) return AppAssets.mascotHappy;
    return AppAssets.mascotHello;
  }

  @override
  Widget build(BuildContext context) {
    final c = AdherenceHistoryScope.of(context);
    if (_shownDay != c.selectedDay) {
      _dayDirection =
          _shownDay == null ? 0 : c.selectedDay.compareTo(_shownDay!).sign;
      _shownDay = c.selectedDay;
    }
    final entranceOffset = _dayDirection == 0
        ? const Offset(0, 8)
        : HistoryMotion.travel(_dayDirection);
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
    final now = _now();
    final isToday = c.selectedDay == c.today;
    // The "Bây giờ" line goes before the first dose still ahead (or after the last one).
    final nowBefore = isToday
        ? doses.where((d) => d.scheduledAt.isAfter(now)).firstOrNull
        : null;
    final nowAfterLast = isToday && nowBefore == null && doses.isNotEmpty;
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
    var sectionIndex = 0;
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
                  mascot: _todayMascot(c),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (preview != null) const AppPreviewBadge(),
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
                          offset: entranceOffset,
                          child: ReminderDayOverview(
                              day: c.selectedDay, today: c.today, group: group),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          key: const Key('history-day-swipe'),
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: (_) => _drag = 0,
                          onHorizontalDragUpdate: (d) =>
                              _drag += d.primaryDelta ?? 0,
                          onHorizontalDragEnd: _swipeDay,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (doses.isEmpty) const HistoryEmpty(),
                              for (final section in sections.entries)
                                HistoryEntrance(
                                  key: ValueKey(
                                      (c, c.contentRevision, section.key)),
                                  index: ++sectionIndex,
                                  offset: entranceOffset,
                                  child: Container(
                                    key: ValueKey(section.key),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _ReminderPeriodHeader(
                                          title: section.key,
                                          doses: section.value,
                                          isConfirmed: c.isHomeConfirmed,
                                        ),
                                        const SizedBox(height: 6),
                                        for (final (i, dose)
                                            in section.value.indexed) ...[
                                          if (dose == nowBefore)
                                            NowMarker(now: now),
                                          _railedTile(
                                            c: c,
                                            dose: dose,
                                            now: now,
                                            asOf: asOf,
                                            first: i == 0,
                                            last: i == section.value.length - 1,
                                          ),
                                          if (nowAfterLast &&
                                              dose == doses.last)
                                            NowMarker(now: now),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
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

  Widget _railedTile({
    required AdherenceHistoryController c,
    required HistoryDose dose,
    required DateTime now,
    required DateTime? asOf,
    required bool first,
    required bool last,
  }) {
    final confirmed = c.isHomeConfirmed(dose);
    final upcoming = !confirmed &&
        dose.status == HistoryDoseStatus.pending &&
        dose.scheduledAt.isAfter(now);
    final minutesLeft = upcoming
        ? (dose.scheduledAt.difference(now).inSeconds / 60).ceil()
        : null;
    // The rail is laid out against the tile's own height (a tile uses LayoutBuilder, so it
    // cannot be measured with IntrinsicHeight).
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.only(left: DoseRailSegment.width + 4),
        child: DoseHistoryTile(
          key: ValueKey((dose.scheduleId, dose.scheduledAt)),
          dose: dose,
          prototypeStyle: true,
          details: _scheduleDetails(c.scheduleById(dose.scheduleId)),
          locallyConfirmed: confirmed,
          countdownMinutes:
              minutesLeft != null && minutesLeft < 60 ? minutesLeft : null,
          onTap: asOf == null ? null : () => unawaited(_openPage(dose: dose)),
          upcoming: upcoming,
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: DoseRailSegment.width,
        child: DoseRailSegment(
            passed: !dose.scheduledAt.isAfter(now), first: first, last: last),
      ),
    ]);
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
    final animate = HistoryMotion.enabled(context);
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
        ClipRect(
          child: AnimatedSwitcher(
            duration: animate ? HistoryMotion.selection : Duration.zero,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(begin: const Offset(0, .8), end: Offset.zero)
                  .animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text('$completed/${doses.length}',
                key: ValueKey(('period-count', title, completed)),
                style: AppTextStyles.captionStrong
                    .copyWith(color: palette.foreground, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}
