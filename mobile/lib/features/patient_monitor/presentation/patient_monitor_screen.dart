import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../adherence/domain/entities/adherence_history.dart';
import '../../family_link/presentation/state/family_link_scope.dart';
import '../../patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import '../domain/monitor_models.dart';
import 'patient_monitor_controller.dart';

const mealMockLabel = 'Dữ liệu minh họa — đang chờ kết nối dữ liệu bữa ăn';

String _handlingLabel(String value) => switch (value) {
      'tranh_phoi_hop' => 'Tránh phối hợp',
      'can_theo_doi' => 'Cần theo dõi',
      'cach_gio' => 'Dùng cách giờ theo hướng dẫn chuyên môn',
      'giam_lieu' => 'Hỏi bác sĩ hoặc dược sĩ về điều chỉnh liều',
      _ => 'Hỏi bác sĩ hoặc dược sĩ về cách xử lý',
    };

class PatientMonitorScreen extends StatefulWidget {
  const PatientMonitorScreen({super.key, required this.patientId});
  final String patientId;
  @override
  State<PatientMonitorScreen> createState() => _PatientMonitorScreenState();
}

class _PatientMonitorScreenState extends State<PatientMonitorScreen> {
  String _view = 'welcome';
  OccurrenceKey? _doseKey;
  int _monthOffset = 0;
  bool _monthly = false;
  Timer? _ticker;
  PatientMonitorController? get _controller =>
      FamilyLinkScope.maybeOf(context)?.monitor;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _view == 'dose') setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _backToHub() {
    _controller?.leave();
    Navigator.of(context).pop();
  }

  void _open(String view) {
    setState(() => _view = view);
    if (view == 'history') _loadRange();
    if (view == 'interactions') unawaited(_controller?.loadInteractions());
  }

  void _loadRange() {
    final controller = _controller;
    if (controller == null) return;
    final today = monitorDay(controller.clock());
    final month = DateTime.utc(today.year, today.month + _monthOffset);
    final start =
        _monthly ? month : today.subtract(Duration(days: today.weekday - 1));
    final end = _monthly && _monthOffset < 0
        ? DateTime.utc(month.year, month.month + 1, 0)
        : today;
    unawaited(controller.loadHistory(start, end));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Người bệnh')),
          body: const Center(child: Text('Chưa kết nối dữ liệu theo dõi.')));
    }
    return ListenableBuilder(
        listenable: Listenable.merge([controller, controller.reminders]),
        builder: (context, _) {
          final valid = controller.ready &&
              !controller.denied &&
              controller.patientId == widget.patientId;
          return PopScope(
            canPop: _view == 'welcome' || _view == 'today' || !valid,
            onPopInvokedWithResult: (popped, _) {
              if (!popped) _open('today');
            },
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                    tooltip: 'Quay lại',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _view == 'today' || _view == 'welcome' || !valid
                        ? _backToHub
                        : () => _open('today')),
                title: Text(
                    valid ? controller.patientName : 'Thông tin được chia sẻ'),
                actions: [
                  if (valid)
                    const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Chip(
                            avatar: Icon(Icons.visibility_outlined, size: 16),
                            label: Text('Chỉ xem')))
                ],
              ),
              body: SafeArea(
                  child: !valid
                      ? _lostAccess(controller)
                      : RefreshIndicator(
                          onRefresh: () async {
                            await controller.refresh();
                            if (_view == 'history') _loadRange();
                            if (_view == 'interactions') {
                              await controller.loadInteractions();
                            }
                            if (_view == 'dose' && _doseKey != null) {
                              await controller.reminders.loadStatus(_doseKey!);
                            }
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.page),
                            children: controller.loading
                                ? [
                                    const LinearProgressIndicator(),
                                    const SizedBox(height: 24),
                                    const Text('Đang tải dữ liệu được chia sẻ…')
                                  ]
                                : controller.error != null
                                    ? [
                                        Text(controller.error!),
                                        TextButton(
                                            onPressed: controller.refresh,
                                            child: const Text('Thử lại'))
                                      ]
                                    : controller.snapshot == null
                                        ? [
                                            const Text(
                                                'Chưa có dữ liệu được chia sẻ.')
                                          ]
                                        : switch (_view) {
                                            'welcome' => [
                                                _section(
                                                    'Bạn đang được chia sẻ thông tin',
                                                    [
                                                      const Text(
                                                          'Bạn có thể xem lịch uống, tủ thuốc và lịch sử theo chia sẻ chung hiện tại. Quyền được kiểm tra lại mỗi lần tải.'),
                                                      const SizedBox(
                                                          height: 16),
                                                      FilledButton(
                                                          onPressed: () =>
                                                              _open('today'),
                                                          child: const Text(
                                                              'Xem hôm nay')),
                                                    ])
                                              ],
                                            'dose' => _doseDetail(controller),
                                            'meals' => _meals(),
                                            'medications' =>
                                              _cabinet(controller),
                                            'interactions' =>
                                              _interactions(controller),
                                            'history' => _history(controller),
                                            _ => _today(controller),
                                          },
                          ),
                        )),
            ),
          );
        });
  }

  Widget _lostAccess(PatientMonitorController controller) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.inkMuted),
            const SizedBox(height: 16),
            Text(
                controller.ready
                    ? 'Hiện không thể truy cập dữ liệu được chia sẻ'
                    : 'Cần kết nối và phiên đăng nhập để xem thông tin.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: _backToHub, child: const Text('Về Người thân')),
          ])));

  Widget _section(String title, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border)),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: AppTextStyles.heading),
            const SizedBox(height: 12),
            ...children,
          ])));

  List<Widget> _today(PatientMonitorController controller) {
    final data = controller.snapshot!;
    final doses = data.dosesForDay(controller.clock());
    final confirmed = doses.where((d) => d.takenAt != null).length;
    final attention = doses.where((d) =>
        d.takenAt == null && d.scheduledAt.isBefore(data.report.history.asOf));
    return [
      Text('Hôm nay · ${adherenceDateQuery(monitorDay(controller.clock()))}',
          style: AppTextStyles.heading),
      const SizedBox(height: 8),
      Text('Cập nhật dữ liệu lúc ${monitorTime(data.report.history.asOf)}'),
      Text(
          data.report.checkpoint == null
              ? 'Chưa có mốc đồng bộ từ điện thoại người bệnh'
              : 'Điện thoại người bệnh đồng bộ: ${adherenceDateQuery(vietnamWallTime(data.report.checkpoint!))} ${monitorTime(data.report.checkpoint!)}',
          style: AppTextStyles.caption),
      const SizedBox(height: 16),
      if (attention.isNotEmpty)
        _section('Liều cần chú ý', [
          const Text(
              'Chưa xác nhận không đồng nghĩa chưa uống. Hãy kiểm tra thông tin với người bệnh.'),
          for (final dose in attention) _doseTile(controller, dose),
        ]),
      _section('Đã xác nhận $confirmed/${doses.length} liều', [
        if (doses.isEmpty) const Text('Chưa có lịch uống trong hôm nay.'),
        for (final dose in doses) _doseTile(controller, dose),
      ]),
      _section('Thông tin theo dõi', [
        ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Tủ thuốc'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open('medications')),
        ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Lịch sử tuân thủ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open('history')),
        ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Tương tác thuốc và thực phẩm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open('interactions')),
      ]),
      _section('Bữa ăn', [
        const Text(mealMockLabel, style: AppTextStyles.caption),
        const SizedBox(height: 8),
        const Text('Xem ba bữa ăn minh họa'),
        TextButton(
            onPressed: () => _open('meals'),
            child: const Text('Xem bữa ăn minh họa'))
      ]),
    ];
  }

  Widget _doseTile(PatientMonitorController controller, AdherenceDose dose) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
            dose.takenAt == null ? Icons.schedule : Icons.check_circle_outline),
        title:
            Text('${monitorTime(dose.scheduledAt)} · ${dose.medicationName}'),
        subtitle: Text(_status(dose, controller.snapshot!.report.history.asOf)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _doseKey = (dose.scheduleId, dose.scheduledAt.toUtc());
          _open('dose');
          if (dose.scheduledAt.isBefore(controller.clock())) {
            unawaited(controller.reminders.loadStatus(_doseKey!));
          }
        },
      );

  String _status(AdherenceDose dose, DateTime asOf) {
    if (dose.takenAt != null) {
      return '${dose.status.label} · xác nhận ${monitorTime(dose.takenAt!)}';
    }
    if (dose.status == AdherenceDoseStatus.pending &&
        dose.scheduledAt.isBefore(asOf)) {
      return 'Quá giờ · chưa xác nhận';
    }
    return dose.scheduledAt.isAfter(asOf) ? 'Sắp đến giờ' : dose.status.label;
  }

  List<Widget> _doseDetail(PatientMonitorController controller) {
    final key = _doseKey;
    if (key == null) return [const Text('Không tìm thấy lần uống.')];
    final matches = controller.snapshot!.dosesForDay(controller.clock()).where(
        (d) => d.scheduleId == key.$1 && d.scheduledAt.toUtc() == key.$2);
    if (matches.isEmpty) {
      return [const Text('Lần uống đã thay đổi. Hãy tải lại hôm nay.')];
    }
    final dose = matches.first, reminder = controller.reminders;
    final receipt = reminder.receipt(key), wait = reminder.wait(key);
    final canRemind = dose.takenAt == null &&
        dose.scheduledAt.isBefore(controller.clock()) &&
        dose.scheduledAt
            .isAfter(controller.clock().subtract(const Duration(days: 30)));
    final history = controller.snapshot!.report.history;
    return [
      _section(dose.medicationName, [
        Text('Giờ dự kiến: ${monitorTime(dose.scheduledAt)}'),
        Text(_status(dose, history.asOf)),
        const SizedBox(height: 16),
        if (receipt != null)
          Text('Yêu cầu nhắc ghi nhận lúc ${monitorTime(receipt.requestedAt)}\n'
              '${switch (receipt.status) {
            'dispatched' => 'Kênh gửi đã chấp nhận',
            'cancelled' => 'Đã hủy gửi',
            'failed' => 'Không gửi được',
            _ => 'Đã nhận yêu cầu'
          }}'),
        if (reminder.message(key) != null) Text(reminder.message(key)!),
        if (canRemind)
          FilledButton.icon(
              onPressed: reminder.busy(key) || wait > Duration.zero
                  ? null
                  : () => reminder.send(key),
              icon: const Icon(Icons.notifications_outlined),
              label: Text(reminder.busy(key)
                  ? 'Đang gửi…'
                  : wait > Duration.zero
                      ? 'Nhắc lại sau ${wait.inSeconds + 1}s'
                      : 'Gửi lời nhắc kiểm tra lịch')),
        const SizedBox(height: 8),
        const Text(
            'Lời nhắc không phải hướng dẫn uống bù. Đã gửi yêu cầu không đồng nghĩa người bệnh đã nhận hoặc đọc.',
            style: AppTextStyles.caption),
      ]),
      _section('Các lần uống trong 7 ngày', [
        for (final group in history.groups)
          for (final item
              in group.doses.where((d) => d.scheduleId == dose.scheduleId))
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${adherenceDateQuery(group.date)} · ${monitorTime(item.scheduledAt)}'),
                subtitle: Text(_status(item, history.asOf))),
      ]),
    ];
  }

  List<Widget> _meals() => [
        const Text(mealMockLabel, style: AppTextStyles.bodyStrong),
        const SizedBox(height: 16),
        for (final meal in const [
          ('Bữa sáng', 'Cháo rau củ'),
          ('Bữa trưa', 'Cơm, cá và rau'),
          ('Bữa tối', 'Chưa chọn')
        ])
          _section(meal.$1, [
            const Icon(Icons.restaurant_outlined,
                size: 48, color: AppColors.inkMuted),
            const SizedBox(height: 12),
            Text(meal.$2),
            const Text('Minh họa, không phải lựa chọn thực tế của người bệnh.',
                style: AppTextStyles.caption)
          ]),
      ];

  List<Widget> _cabinet(PatientMonitorController controller) => [
        Text('Tủ thuốc · ${controller.snapshot!.medications.length} thuốc',
            style: AppTextStyles.heading),
        const SizedBox(height: 16),
        if (controller.snapshot!.medications.isEmpty)
          const Text('Chưa có thuốc đang dùng.'),
        for (final medication in controller.snapshot!.medications)
          _section(medication.name, [
            Text(medication.strength),
            Text(
                '${medication.dosePerIntake} ${medication.unit}/lần · ${medication.frequency.label}'),
            Text(medication.timing.label),
            Text(medication.stockRemaining == null
                ? 'Chưa cập nhật số lượng'
                : medication.stockRemaining == 0
                    ? 'Hết thuốc'
                    : 'Còn ${medication.stockRemaining} ${medication.unit}'),
          ]),
      ];

  List<Widget> _interactions(PatientMonitorController controller) {
    final drugs = controller.interactions, food = controller.food;
    if (controller.interactionError != null) {
      return [
        Text(controller.interactionError!),
        TextButton(
            onPressed: controller.loadInteractions,
            child: const Text('Thử lại'))
      ];
    }
    if (drugs == null || food == null) return [const LinearProgressIndicator()];
    String label(Object? status) => switch (status) {
          'co_tuong_tac' => 'Có tương tác',
          'da_kiem_tra_khong_thay' => 'Đã kiểm tra, không thấy tương tác',
          _ => 'Chưa đủ dữ liệu',
        };
    return [
      _section('Thuốc – thuốc', [
        Text(drugs.status.label),
        for (final finding in drugs.interactions)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  '${finding.ingredientAName} – ${finding.ingredientBName}\n'
                  'Mức ${finding.severityLevel}\n${finding.description}\n${finding.warningMessage}\n'
                  '${_handlingLabel(finding.handlingType)}${finding.minIntervalHours == null ? '' : ' · ${finding.minIntervalHours} giờ'}\nNguồn: ${finding.source}')),
        for (final missing in drugs.insufficientDataMedications)
          Text('${missing.medicationName}: ${missing.reason}'),
        const SizedBox(height: 12),
        Text(drugs.disclaimer, style: AppTextStyles.caption),
      ]),
      _section('Thuốc – thực phẩm', [
        Text(label(food['status'])),
        for (final medication in food['medications'] as List) ...[
          const Divider(),
          Text(
              '${medication['medication']['name']} · ${label(medication['status'])}',
              style: AppTextStyles.bodyStrong),
          for (final warning in medication['warnings'] as List)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    '${warning['food_to_avoid']} · Mức ${warning['severity_level']}\n${warning['reason']}\nNguồn: ${warning['source']}')),
        ],
        const SizedBox(height: 12),
        Text(food['disclaimer'] as String, style: AppTextStyles.caption),
      ]),
    ];
  }

  List<Widget> _history(PatientMonitorController controller) {
    final history = controller.range?.history, summary = history?.summary;
    return [
      SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Tuần')),
            ButtonSegment(value: true, label: Text('Tháng'))
          ],
          selected: {
            _monthly
          },
          onSelectionChanged: (value) {
            setState(() {
              _monthly = value.single;
              _monthOffset = 0;
            });
            _loadRange();
          }),
      if (_monthly)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              tooltip: 'Tháng trước',
              onPressed: _monthOffset > -2
                  ? () {
                      setState(() => _monthOffset--);
                      _loadRange();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left)),
          Text(
              _monthOffset == 0 ? 'Tháng này' : '${-_monthOffset} tháng trước'),
          IconButton(
              tooltip: 'Tháng sau',
              onPressed: _monthOffset < 0
                  ? () {
                      setState(() => _monthOffset++);
                      _loadRange();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right)),
        ]),
      const SizedBox(height: 16),
      if (controller.rangeError != null) ...[
        Text(controller.rangeError!),
        TextButton(onPressed: _loadRange, child: const Text('Thử lại'))
      ] else if (history == null)
        const LinearProgressIndicator()
      else ...[
        _section('Tỷ lệ tuân thủ', [
          Text(
              summary!.rate == null
                  ? 'Chưa có dữ liệu đủ điều kiện'
                  : '${summary.rate!.toStringAsFixed(2)}%',
              style: AppTextStyles.heading),
          Text(
              '${adherenceDateQuery(history.from)} – ${adherenceDateQuery(history.to)}'),
          Text(
              'Đúng giờ ${summary.taken} · Muộn ${summary.late} · Bỏ lỡ ${summary.missed}\nChờ ${summary.pending} · Chưa xác minh ${summary.unverified}'),
        ]),
        if (history.groups.isEmpty)
          const Text('Chưa có lịch sử trong khoảng này.'),
        for (final group in history.groups)
          _section(adherenceDateQuery(group.date), [
            for (final dose in group.doses)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${monitorTime(dose.scheduledAt)} · ${dose.medicationName}'),
                  subtitle: Text(_status(dose, history.asOf))),
          ]),
      ],
    ];
  }
}
