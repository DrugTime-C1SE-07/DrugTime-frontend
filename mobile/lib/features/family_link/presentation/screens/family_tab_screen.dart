import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/app_shell.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../family/presentation/state/family_alert_scope.dart';
import '../../../consent/domain/entities/consent.dart';
import '../../../consent/presentation/state/consent_controller.dart';
import '../state/family_link_scope.dart';
import '../state/incoming_requests_controller.dart';
import '../widgets/incoming_requests_section.dart';
import '../state/caregivers_controller.dart';
import '../../../patient_monitor/presentation/patient_monitor_controller.dart';
import '../../../patient_monitor/domain/monitor_models.dart';

const _familyPurple = Color(0xFF5B3FA8);

/// Tab "Người thân": yêu cầu theo dõi đang chờ người dùng duyệt, chia sẻ mã của mình (màn QR
/// của 3.11, link mời) và theo dõi người thân mới.
///
/// Người giám sát đã chấp thuận được quản lý ở Hồ sơ > Người giám sát.
class FamilyTabScreen extends StatefulWidget {
  const FamilyTabScreen({super.key, this.active = true});

  /// Tab đang hiển thị. Chuyển sang `true` thì tải lại yêu cầu đang chờ (không cache).
  final bool active;

  @override
  State<FamilyTabScreen> createState() => _FamilyTabScreenState();
}

class _FamilyTabScreenState extends State<FamilyTabScreen> {
  IncomingRequestsController? _requests;
  bool _ownsController = false;
  int _tab = 0;
  CaregiversController? _caregiverState;
  CaregiversController get _caregivers => _caregiverState ??=
      CaregiversController(FamilyLinkScope.read(context).caregivers);
  PatientMonitorController? get _monitor =>
      FamilyLinkScope.maybeOf(context)?.monitor;

  IncomingRequestsController get _controller {
    if (_requests != null) return _requests!;
    final shared = FamilyLinkScope.maybeOf(context)?.incomingRequests;
    if (shared != null) {
      _requests = shared;
      _ownsController = false;
      return shared;
    }
    _ownsController = true;
    return _requests =
        IncomingRequestsController(FamilyLinkScope.read(context).caregivers);
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _queueLoad();
  }

  @override
  void didUpdateWidget(FamilyTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _queueLoad();
    if (!widget.active && oldWidget.active) _monitor?.setHubActive(false);
  }

  void _queueLoad() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_controller.load());
          if (_monitor != null) unawaited(_caregivers.load());
          _monitor?.setHubActive(widget.active && _tab == 0);
        }
      });

  @override
  void dispose() {
    if (_ownsController) {
      _requests?.dispose();
    }
    _caregiverState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = FamilyAlertScope.maybeOf(context)?.unreadCount;
    final sharingGranted =
        ConsentScope.of(context).isGranted(ConsentPurpose.familySharing);
    return ListenableBuilder(
        listenable: Listenable.merge([
          if (_monitor != null) ...[_caregivers, _monitor!]
        ]),
        builder: (context, _) => Scaffold(
              appBar: AppBar(
                  leading: IconButton(
                      tooltip: 'Về trang chủ',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => AppShell.showTab(context, AppTab.home)),
                  title: const Text('Người thân'),
                  actions: [
                    IconButton(
                        tooltip: 'Cảnh báo người thân',
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.familyAlerts),
                        icon: Badge(
                            isLabelVisible: unread != null && unread > 0,
                            label: Text('$unread'),
                            child: const Icon(Icons.notifications_outlined)))
                  ]),
              body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _controller.load(),
                      if (_monitor != null) _caregivers.load(),
                      if (_monitor != null) _monitor!.loadHub()
                    ]);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      const Text('Cùng nhau uống thuốc đúng giờ',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 16),
                      if (_monitor != null) ...[
                        SegmentedButton<int>(
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? _familyPurple
                                          : Colors.white),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? Colors.white
                                          : AppColors.inkMuted),
                              side:
                                  const WidgetStatePropertyAll(BorderSide.none),
                            ),
                            segments: [
                              ButtonSegment(
                                  value: 0,
                                  label: Text(
                                      'Tôi theo dõi (${_monitor!.linked.patients.length})')),
                              ButtonSegment(
                                  value: 1,
                                  label: Text(
                                      'Theo dõi tôi (${_caregivers.items.length})')),
                            ],
                            selected: {_tab},
                            onSelectionChanged: (value) {
                              setState(() => _tab = value.single);
                              _monitor
                                  ?.setHubActive(widget.active && _tab == 0);
                            }),
                        const SizedBox(height: 16),
                        if (_tab == 0) ..._patientCards(context, _monitor!),
                        if (_tab == 1) ...[
                          if (_caregivers.isLoading)
                            const LinearProgressIndicator(),
                          if (_caregivers.loadError != null)
                            const Text(
                                'Chưa tải được người giám sát. Kéo xuống để thử lại.'),
                          if (_caregivers.isLoaded &&
                              _caregivers.loadError == null &&
                              _caregivers.items.isEmpty)
                            const Text('Chưa có người giám sát'),
                          for (final person in _caregivers.items)
                            Card(
                                child: ListTile(
                              title: Text(person.familyName ?? 'Người thân'),
                              subtitle: Text(person.sharingEnabled
                                  ? 'Đang chia sẻ thông tin'
                                  : 'Đã tắt chia sẻ'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.of(context)
                                    .pushNamed(AppRoutes.caregivers);
                                if (mounted) unawaited(_caregivers.load());
                              },
                            )),
                        ],
                      ],
                      if (_monitor == null || _tab == 1)
                        IncomingRequestsSection(
                          controller: _controller,
                          sharingConsentGranted: sharingGranted,
                        ),
                      if (_monitor == null)
                        _EntryCard(
                          key: const Key('family-alerts'),
                          icon: Icons.notifications_outlined,
                          title: 'Cảnh báo người thân',
                          subtitle: unread == null
                              ? 'Mở hộp thư cảnh báo'
                              : '$unread chưa đọc',
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.familyAlerts),
                        ),
                      if (_monitor == null)
                        const SizedBox(height: AppSpacing.md),
                      if (_monitor == null)
                        _EntryCard(
                          key: const Key('family-my-code'),
                          icon: Icons.qr_code_2,
                          title: 'Mã liên kết của tôi',
                          subtitle:
                              'Cho người thân quét hoặc nhập để theo dõi bạn',
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.familyMyCode),
                        ),
                      if (_monitor == null)
                        const SizedBox(height: AppSpacing.md),
                      if (_monitor == null)
                        _EntryCard(
                          key: const Key('family-share-link'),
                          icon: Icons.share_outlined,
                          title: 'Gửi link mời',
                          subtitle:
                              'Gửi qua Zalo, tin nhắn hoặc email để người thân theo dõi bạn',
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.familyShareLink),
                        ),
                      if (_monitor == null)
                        const SizedBox(height: AppSpacing.md),
                      if (_monitor == null)
                        _EntryCard(
                          key: const Key('family-follow'),
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'Theo dõi người thân',
                          subtitle: 'Quét mã QR hoặc nhập mã của người thân',
                          onTap: () =>
                              unawaited(showFollowMethodSheet(context)),
                        ),
                      if (_monitor != null && _tab == 0) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('family-follow'),
                          onPressed: () =>
                              unawaited(showFollowMethodSheet(context)),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Theo dõi thêm người'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: _familyPurple,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ));
  }

  List<Widget> _patientCards(
      BuildContext context, PatientMonitorController monitor) {
    if (!monitor.ready || monitor.hubError != null) {
      return [
        Text(monitor.hubError ?? 'Cần kết nối để xem thông tin.'),
        TextButton(
            onPressed: monitor.ready ? monitor.loadHub : null,
            child: const Text('Thử lại'))
      ];
    }
    if (monitor.loadingHub) return [const LinearProgressIndicator()];
    if (monitor.linked.patients.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.people_outline, size: 64, color: _familyPurple),
              SizedBox(height: 16),
              Text('Bạn chưa theo dõi ai',
                  style: AppTextStyles.heading, textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('Quét mã QR trên máy người thân để gửi yêu cầu theo dõi.',
                  textAlign: TextAlign.center),
            ]))
      ];
    }
    return [
      for (final patient in monitor.linked.patients)
        Card(
            child: ListTile(
          key: ValueKey('patient-${patient.id}'),
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(patient.name.isEmpty ? 'Người bệnh' : patient.name),
          subtitle: _summary(monitor, patient.id),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            unawaited(monitor.select(patient.id));
            monitor.setHubActive(false);
            Navigator.of(context)
                .pushNamed(AppRoutes.patientMonitor, arguments: patient.id)
                .then((_) {
              if (mounted) monitor.setHubActive(widget.active && _tab == 0);
            });
          },
        ))
    ];
  }

  Widget _summary(PatientMonitorController monitor, String id) {
    if (monitor.summaryErrors.contains(id)) {
      return const Text('Chưa tải đủ dữ liệu · Kéo xuống để thử lại');
    }
    final data = monitor.summaries[id];
    if (data == null) return const Text('Đang tải hôm nay…');
    final doses = data.dosesForDay(monitor.clock());
    final confirmed = doses.where((d) => d.takenAt != null).length;
    final attention = doses.where((d) =>
        d.takenAt == null && d.scheduledAt.isBefore(data.report.history.asOf));
    final upcoming =
        doses.where((d) => d.scheduledAt.isAfter(data.report.history.asOf));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text('Đã xác nhận $confirmed/${doses.length} liều'),
      const SizedBox(height: 8),
      if (doses.isNotEmpty)
        LinearProgressIndicator(
          value: confirmed / doses.length,
          semanticsLabel: 'Đã xác nhận $confirmed trên ${doses.length} liều',
          minHeight: 8,
        ),
      const SizedBox(height: 8),
      Text(attention.isEmpty ? 'Hôm nay' : 'Có liều cần chú ý'),
      if (upcoming.isNotEmpty)
        Text('Liều tiếp theo ${monitorTime(upcoming.first.scheduledAt)}'),
      Text('Cập nhật ${monitorTime(data.report.history.asOf)}'),
    ]);
  }
}

/// Chọn cách đưa mã của người thân vào app.
Future<void> showFollowMethodSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Theo dõi người thân', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Người thân cần chấp thuận thì bạn mới xem được thông tin của họ.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              key: const Key('follow-method-scan'),
              leading:
                  const Icon(Icons.qr_code_scanner, color: AppColors.brand),
              title: const Text('Quét mã QR', style: AppTextStyles.bodyStrong),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                    Navigator.of(context).pushNamed(AppRoutes.familyScanCode));
              },
            ),
            ListTile(
              key: const Key('follow-method-enter'),
              leading:
                  const Icon(Icons.keyboard_outlined, color: AppColors.brand),
              title: const Text('Nhập mã', style: AppTextStyles.bodyStrong),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                    Navigator.of(context).pushNamed(AppRoutes.familyEnterCode));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.brandTint,
          child: Icon(icon, color: AppColors.brand),
        ),
        title: Text(title, style: AppTextStyles.bodyStrong),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        onTap: onTap,
      ),
    );
  }
}
