import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
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

  Future<void> _openPage({bool medication = false}) async {
    final c = _controller!;
    if (!widget.active ||
        _opening ||
        _detailRoute != null ||
        c.error?.removesAccess == true) {
      return;
    }
    _opening = true;
    final revision = c.accessRevision;
    final route = HistoryPageRoute<void>(
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      settings: RouteSettings(
          name: medication ? 'adherence-medication' : 'adherence-month'),
      builder: (_) => medication
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

  @override
  Widget build(BuildContext context) {
    final c = AdherenceHistoryScope.of(context);
    final group = c.selectedGroup;
    final doses = List<HistoryDose>.of(group?.doses ?? const [])
      ..sort((a, b) {
        final order = a.scheduledAt.compareTo(b.scheduledAt);
        return order != 0 ? order : a.scheduleId.compareTo(b.scheduleId);
      });
    final blocked = c.error?.removesAccess == true;
    final heading = HistoryInlineRow(children: [
      const Text('Lịch nhắc',
          key: Key('history-title'), style: AppTextStyles.title),
      if (AppPreviewScope.maybeOf(context) != null) const AppPreviewBadge(),
    ]);
    final actions = <Widget>[
      const HistoryInfoButton(),
      IconButton(
          tooltip: 'Mở lịch tháng',
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
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                    child: HistorySummary(
                        summary: group?.summary,
                        day: c.selectedDay,
                        today: c.today)),
                const SizedBox(height: AppSpacing.lg),
                if (doses.isEmpty) const HistoryEmpty(),
                for (final (index, dose) in doses.indexed)
                  HistoryEntrance(
                      key: ValueKey((
                        c,
                        c.contentRevision,
                        dose.scheduleId,
                        dose.scheduledAt
                      )),
                      index: index,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(children: [
                                const ExcludeSemantics(
                                    child: Icon(Icons.schedule,
                                        size: 16, color: AppColors.inkMuted)),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                    child: Text(
                                        HistoryFormat.time(dose.scheduledAt),
                                        style: AppTextStyles.caption)),
                              ]),
                            ),
                            DoseHistoryTile(dose: dose),
                            const SizedBox(height: AppSpacing.xs),
                          ])),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        )));
  }
}
