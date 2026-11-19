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
import '../../../patient_monitor/domain/monitor_digest.dart';
import '../../../patient_monitor/presentation/widgets/monitor_palette.dart';
import '../garden/care_garden.dart';
import '../garden/garden_mood.dart';
import '../widgets/patient_summary_card.dart';

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
                        if (_tab == 0) ...[
                          _garden(context, _monitor!),
                          const SizedBox(height: 16),
                        ],
                        _Segments(
                          selected: _tab,
                          labels: [
                            'Tôi theo dõi · ${_monitor!.linked.patients.length}',
                            'Theo dõi tôi · ${_caregivers.items.length}',
                          ],
                          onChanged: (value) {
                            setState(() => _tab = value);
                            _monitor?.setHubActive(widget.active && _tab == 0);
                          },
                        ),
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
                      if (_monitor != null &&
                          _tab == 0 &&
                          _monitor!.linked.patients.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _DashedButton(
                          key: const Key('family-follow'),
                          onPressed: () =>
                              unawaited(showFollowMethodSheet(context)),
                          icon: Icons.qr_code_scanner,
                          label: 'Theo dõi thêm người',
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
    if (monitor.linked.patients.isEmpty) return [_emptyState(context)];
    return [
      for (final patient in monitor.linked.patients)
        PatientSummaryCard(
          key: ValueKey('patient-${patient.id}'),
          patientId: patient.id,
          name: _displayName(patient.name),
          snapshot: monitor.summaries[patient.id],
          failed: monitor.summaryErrors.contains(patient.id),
          now: monitor.clock(),
          onTap: () => _openPatient(monitor, patient.id),
        ),
    ];
  }

  static String _displayName(String name) => name.isEmpty ? 'Người bệnh' : name;

  void _openPatient(PatientMonitorController monitor, String id) {
    unawaited(monitor.select(id));
    monitor.setHubActive(false);
    Navigator.of(context)
        .pushNamed(AppRoutes.patientMonitor, arguments: id)
        .then((_) {
      if (mounted) monitor.setHubActive(widget.active && _tab == 0);
    });
  }

  CareMood? _moodOf(PatientMonitorController monitor, String id) {
    final data = monitor.summaries[id];
    if (data == null) return null;
    // Hub không tải trạng thái nhắc của từng người: chỉ phân biệt ổn / bỏ lỡ / uống bù.
    return careMood(data.dosesForDay(monitor.clock()), data.report.history.asOf,
        nudged: (_) => false);
  }

  /// Banner khu vườn: mỗi người được theo dõi là một chậu cây; chạm chậu để mở người đó.
  Widget _garden(BuildContext context, PatientMonitorController monitor) {
    final patients = monitor.linked.patients;
    final moods = {for (final p in patients) p.id: _moodOf(monitor, p.id)};
    final mood = patients.isEmpty
        ? GardenMood.empty
        : moods.values.any((m) => m == CareMood.missed || m == CareMood.overdue)
            ? GardenMood.missed
            : moods.values.contains(CareMood.recovered)
                ? GardenMood.recovered
                : GardenMood.ok;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CareGarden(
        key: const Key('family-garden'),
        height: 190,
        mood: mood,
        plants: [
          for (final p in patients)
            GardenPlant(
              id: p.id,
              label: 'Chậu cây của ${_displayName(p.name)}',
              shape: moods[p.id] == null
                  ? PlantShape.bloom
                  : plantShapeFor(moods[p.id]!),
            ),
        ],
        onPlantTap: (id) => _openPatient(monitor, id),
      ),
    );
  }

  /// R1e: chưa theo dõi ai.
  Widget _emptyState(BuildContext context) {
    const steps = [
      'Người thân mở Hồ sơ › Chia sẻ và liên kết › Hiện mã QR',
      'Bạn quét mã hoặc nhập mã bằng DrugTime',
      'Người thân bấm Đồng ý',
    ];
    return Column(
      key: const Key('family-empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bạn chưa theo dõi ai',
            style: AppTextStyles.title, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
            'Quét mã QR trên máy người thân để xem họ uống thuốc hằng ngày',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: MonitorColors.purpleTint,
                    child: Text('${i + 1}',
                        style: AppTextStyles.bodyStrong
                            .copyWith(color: _familyPurple)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(steps[i], style: AppTextStyles.body)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('family-empty-scan'),
          onPressed: () => unawaited(
              Navigator.of(context).pushNamed(AppRoutes.familyScanCode)),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Quét mã QR'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('family-empty-enter'),
          onPressed: () => unawaited(
              Navigator.of(context).pushNamed(AppRoutes.familyEnterCode)),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Nhập mã'),
        ),
      ],
    );
  }
}

/// Hai segment "Tôi theo dõi · n" / "Theo dõi tôi · n" dạng viên thuốc.
class _Segments extends StatelessWidget {
  const _Segments(
      {required this.selected, required this.labels, required this.onChanged});
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: selected == i,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: MediaQuery.maybeDisableAnimationsOf(context) == true
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: selected == i ? _familyPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyStrong.copyWith(
                          color: selected == i
                              ? Colors.white
                              : AppColors.inkMuted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Nút viền đứt "Theo dõi thêm người".
class _DashedButton extends StatelessWidget {
  const _DashedButton(
      {super.key,
      required this.onPressed,
      required this.icon,
      required this.label});
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: _familyPurple),
              const SizedBox(width: 8),
              Text(label,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: _familyPurple)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), const Radius.circular(18));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _familyPurple.withValues(alpha: .5);
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
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
