import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../state/adherence_history_controller.dart';
import '../widgets/dose_history_tile.dart';
import '../widgets/history_summary.dart';
import '../widgets/history_week_selector.dart';
import '../widgets/history_motion.dart';
import '../widgets/history_feedback.dart';
import '../../../../core/preview/app_preview_scope.dart';
import '../widgets/history_info_sheet.dart';
import '../widgets/history_inline_row.dart';
import 'adherence_month_screen.dart';
import 'medication_history_screen.dart';

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
    if (_controller == controller) return;
    _controller?.removeListener(_changed);
    _controller = controller..addListener(_changed);
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
    final heading = HistoryInlineRow(children: [
      const Text('Lịch nhắc',
          key: Key('history-title'), style: AppTextStyles.title),
      if (AppPreviewScope.maybeOf(context) != null) const AppPreviewBadge(),
    ]);
    final actions = <Widget>[
      const HistoryInfoButton(),
      IconButton(
          tooltip: 'Mở lịch tháng',
          style: IconButton.styleFrom(backgroundColor: AppColors.surfaceMuted),
          onPressed: blocked ? null : () => unawaited(_openPage()),
          icon: const Icon(Icons.calendar_month_outlined)),
      SizedBox(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          child: PopupMenuButton<String>(
            tooltip: 'Tùy chọn lịch sử',
            enabled: !blocked,
            icon: const Icon(Icons.more_horiz),
            onSelected: (_) => unawaited(_openPage(medication: true)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'medication', child: Text('Theo thuốc'))
            ],
          )),
    ];
    return HistoryMotionScope(
        active: widget.active,
        child: SafeArea(
            child: RefreshIndicator(
          onRefresh: c.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              if (MediaQuery.textScalerOf(context).scale(16) > 22) ...[
                heading,
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions),
              ] else
                Row(children: [Expanded(child: heading), ...actions]),
              const SizedBox(height: AppSpacing.md),
              HistoryWeekSelector(controller: c),
              const SizedBox(height: AppSpacing.lg),
              if (c.loading || c.error != null)
                HistoryLoadState(controller: c, onRetry: widget.onRetry)
              else if (c.history?.mode == HistoryMode.date) ...[
                HistoryEntrance(
                  key: ValueKey((c, c.contentRevision, 'summary')),
                  child: _TodayDoseProgress(
                    summary: group?.summary,
                    day: c.selectedDay,
                    today: c.today,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (doses.isEmpty) const HistoryEmpty(),
                for (final section in sections.entries)
                  HistoryEntrance(
                    key: ValueKey((c, c.contentRevision, section.key)),
                    child: Container(
                      key: ValueKey(section.key),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(section.key,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.inkMuted)),
                          ),
                          for (final dose in section.value)
                            DoseHistoryTile(
                              key:
                                  ValueKey((dose.scheduleId, dose.scheduledAt)),
                              dose: dose,
                              onTap: () => unawaited(_openPage(dose: dose)),
                              upcoming:
                                  dose.status == HistoryDoseStatus.pending &&
                                      asOf != null &&
                                      dose.scheduledAt.isAfter(asOf),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        )));
  }
}

class _TodayDoseProgress extends StatelessWidget {
  const _TodayDoseProgress(
      {required this.summary, required this.day, required this.today});

  final AdherenceSummary? summary;
  final DateTime day, today;

  @override
  Widget build(BuildContext context) {
    final confirmed = (summary?.taken ?? 0) + (summary?.late ?? 0);
    final total = summary?.total ?? 0;
    final weekday = day.weekday == 7 ? 'Chủ nhật' : 'Thứ ${day.weekday + 1}';
    final date =
        '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
    final heading = '${day == today ? 'Hôm nay' : weekday}: $date';
    return Container(
      key: const Key('history-summary'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HistoryInlineRow(spread: true, children: [
            Text(heading, style: AppTextStyles.caption),
            Text('$confirmed/$total liều đã uống',
                style: AppTextStyles.captionStrong
                    .copyWith(color: AppColors.brand)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : confirmed / total,
              backgroundColor: AppColors.surface,
              color: AppColors.brand,
              minHeight: 6,
              semanticsLabel: 'Tiến độ uống thuốc của ngày đã chọn',
            ),
          ),
        ],
      ),
    );
  }
}
