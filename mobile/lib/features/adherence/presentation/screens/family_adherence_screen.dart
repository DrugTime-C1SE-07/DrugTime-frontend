import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_failure.dart';
import '../../domain/repositories/adherence_repository.dart';
import '../state/adherence_controller.dart';
import '../widgets/adherence_date_picker.dart';
import '../widgets/adherence_dose_card.dart';
import '../widgets/adherence_summary_card.dart';

/// A family member can view one patient's history; all authorization stays on the API.
class FamilyAdherenceScreen extends StatefulWidget {
  const FamilyAdherenceScreen({
    super.key,
    required this.patientId,
    required this.repository,
    this.patientName,
    this.now,
  });

  final String patientId;
  final String? patientName;
  final AdherenceRepository repository;
  final DateTime Function()? now;

  @override
  State<FamilyAdherenceScreen> createState() => _FamilyAdherenceScreenState();
}

class _FamilyAdherenceScreenState extends State<FamilyAdherenceScreen>
    with WidgetsBindingObserver, RouteAware {
  late AdherenceController _controller;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AdherenceController(
      widget.repository,
      patientId: widget.patientId,
      now: widget.now,
    );
    unawaited(_controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      familyAdherenceRouteObserver.unsubscribe(this);
      _route = route;
      familyAdherenceRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant FamilyAdherenceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _controller.dispose();
      _controller = AdherenceController(
        widget.repository,
        patientId: widget.patientId,
        now: widget.now,
      );
      unawaited(_controller.load());
    } else if (oldWidget.patientId != widget.patientId) {
      unawaited(_controller.changePatient(widget.patientId));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.refresh());
  }

  @override
  void didPopNext() => unawaited(_controller.refresh());

  @override
  void dispose() {
    familyAdherenceRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lịch sử tuân thủ')),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => RefreshIndicator(
              onRefresh: _controller.refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.lg,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth < 560
                                ? constraints.maxWidth
                                : 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lịch sử của người bệnh được chia sẻ',
                                style: AppTextStyles.caption),
                            if (widget.patientName case final name?
                                when name.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(name.trim(), style: AppTextStyles.heading),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            AdherenceDatePicker(
                              selectedDate: _controller.selectedDate,
                              earliestDate: _controller.earliestDate,
                              today: _controller.today,
                              groups: _controller.history?.groups ?? const [],
                              onSelected: (date) =>
                                  unawaited(_controller.selectDate(date)),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _content(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _content() {
    if (_controller.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Đang tải lịch sử tuân thủ', style: AppTextStyles.body),
            ],
          ),
        ),
      );
    }
    final failure = _controller.failure;
    if (failure != null) return _error(failure.kind);
    final history = _controller.history;
    if (history == null) return const SizedBox.shrink();
    final group = _controller.selectedGroup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng quan ${_shortDate(history.from)} – ${_shortDate(history.to)}',
          style: AppTextStyles.captionStrong,
        ),
        const SizedBox(height: AppSpacing.sm),
        AdherenceSummaryCard(summary: history.summary),
        const SizedBox(height: AppSpacing.xl),
        Text('Liều ngày ${_shortDate(_controller.selectedDate)}',
            style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.md),
        if (group == null)
          const _Message(
            icon: Icons.event_busy_outlined,
            title: 'Không có lịch sử trong ngày này',
            detail: 'Bạn có thể chọn ngày khác để xem.',
          )
        else ...[
          Text(
            '${group.summary.taken + group.summary.late}/${group.summary.total} liều đã uống',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final dose in group.doses) ...[
            AdherenceDoseCard(dose: dose),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }

  Widget _error(AdherenceFailureKind kind) {
    final (icon, title, detail) = switch (kind) {
      AdherenceFailureKind.denied => (
          Icons.shield_outlined,
          'Không còn quyền xem lịch sử',
          'Người bệnh có thể đã thay đổi quyền chia sẻ.'
        ),
      AdherenceFailureKind.unauthorized => (
          Icons.lock_outline,
          'Phiên đăng nhập đã hết hạn',
          'Vui lòng đăng nhập lại.'
        ),
      AdherenceFailureKind.invalidRange => (
          Icons.event_busy_outlined,
          'Khoảng ngày không hợp lệ',
          'Vui lòng chọn ngày khác.'
        ),
      AdherenceFailureKind.network || AdherenceFailureKind.unavailable => (
          Icons.wifi_off_outlined,
          'Chưa thể tải lịch sử',
          'Kiểm tra kết nối và thử lại.'
        ),
      AdherenceFailureKind.invalidResponse => (
          Icons.error_outline,
          'Chưa thể hiển thị lịch sử',
          'Vui lòng thử lại sau.'
        ),
    };
    return _Message(
      icon: icon,
      title: title,
      detail: detail,
      action: _controller.canRetry
          ? TextButton.icon(
              onPressed: () => unawaited(_controller.refresh()),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            )
          : null,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.brand, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                style: AppTextStyles.bodyStrong, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(detail,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      );
}

String _shortDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';
