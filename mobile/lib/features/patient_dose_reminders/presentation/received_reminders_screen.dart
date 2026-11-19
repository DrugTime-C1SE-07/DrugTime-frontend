import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/api/api_exception.dart';
import '../../consent/presentation/state/consent_controller.dart';
import '../../family_link/presentation/state/family_link_scope.dart';
import '../../patient_monitor/domain/monitor_models.dart';
import '../../patient_monitor/presentation/patient_monitor_controller.dart';

class ReceivedRemindersScreen extends StatefulWidget {
  const ReceivedRemindersScreen({super.key, this.reminderId});
  final int? reminderId;
  @override
  State<ReceivedRemindersScreen> createState() =>
      _ReceivedRemindersScreenState();
}

class _ReceivedRemindersScreenState extends State<ReceivedRemindersScreen> {
  PatientMonitorController? _monitor;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _detail;
  String? _doseStatus, _error;
  int? _id;
  int _revision = 0, _session = -1;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monitor = FamilyLinkScope.maybeOf(context)?.monitor;
    if (!identical(monitor, _monitor)) {
      _monitor?.removeListener(_changed);
      _monitor = monitor;
      monitor?.addListener(_changed);
      _session = monitor?.sessionRevision ?? -1;
      _id = widget.reminderId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  bool get _allowed =>
      _monitor?.ready == true && ConsentScope.of(context).hasHealthData;

  void _clear() {
    _revision++;
    _items = [];
    _detail = null;
    _doseStatus = null;
    _loading = false;
  }

  void _changed() {
    if (!mounted) return;
    if (_session != _monitor?.sessionRevision) {
      _session = _monitor?.sessionRevision ?? -1;
      setState(_clear);
      if (_monitor?.ready == true) unawaited(_load());
    }
  }

  Future<void> _load() async {
    final monitor = _monitor;
    if (!mounted || monitor == null || !_allowed) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
      _detail = null;
      _items = [];
      _doseStatus = null;
    });
    bool current() =>
        mounted && revision == _revision && monitor.ready && _allowed;
    try {
      final repo = monitor.reminders.repository;
      if (_id case final id?) {
        final detail = await repo.detail(id);
        if (!current()) return;
        final patient = detail['patient_id'] as String;
        final at = DateTime.parse(detail['scheduled_at'] as String).toUtc();
        final day = monitorDay(at);
        final history = await monitor.repository.history(patient, day, day);
        if (!current()) return;
        final matching = history.history.groups.expand((g) => g.doses).where(
            (dose) =>
                dose.scheduleId == detail['schedule_id'] &&
                dose.scheduledAt.toUtc() == at);
        await repo.markRead(id);
        if (!current()) return;
        _detail = detail;
        final dose = matching.isEmpty ? null : matching.first;
        _doseStatus = dose == null
            ? 'Không ánh xạ được lần uống hiện tại.'
            : dose.takenAt != null
                // liều đã ghi nhận (P1 mở hộp thư thay vì màn xác nhận)
                ? 'Bạn đã uống lúc ${monitorTime(dose.takenAt!)}'
                : dose.status.label;
      } else {
        final items = <Map<String, dynamic>>[];
        for (var offset = 0;; offset += 100) {
          final page = await repo.received(offset: offset);
          if (!current()) return;
          final batch = (page['items'] as List).cast<Map<String, dynamic>>();
          items.addAll(batch);
          if (batch.length < 100) break;
        }
        if (current()) _items = items;
      }
    } on ApiException catch (error) {
      if (current()) {
        _error = const {403, 404}.contains(error.statusCode)
            ? 'Lời nhắc hiện không còn khả dụng.'
            : 'Chưa tải được lời nhắc. Hãy thử lại.';
      }
    } on FormatException {
      if (current()) _error = 'Dữ liệu lời nhắc không hợp lệ.';
    } on TypeError {
      if (current()) _error = 'Dữ liệu lời nhắc không hợp lệ.';
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _clear();
    _monitor?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) _clear();
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Lời nhắc nhận được'),
          leading: _id == null
              ? null
              : IconButton(
                  tooltip: 'Hộp thư',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _id = null;
                    unawaited(_load());
                  })),
      body: SafeArea(
          child: !_allowed
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'Cần kết nối, đăng nhập và đồng ý xử lý dữ liệu sức khỏe để xem lời nhắc.')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_loading) const LinearProgressIndicator(),
                        if (_error != null) ...[
                          Text(_error!),
                          TextButton(
                              onPressed: _load, child: const Text('Thử lại'))
                        ],
                        if (!_loading &&
                            _error == null &&
                            detail == null &&
                            _items.isEmpty)
                          const Text('Chưa có lời nhắc.'),
                        if (detail != null)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                            detail['medication_name'] as String,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        Text(
                                            'Từ ${detail['sender_name'] ?? 'Người thân'}'),
                                        Text(
                                            'Giờ dự kiến: ${monitorTime(DateTime.parse(detail['scheduled_at'] as String))}'),
                                        Text(_doseStatus ??
                                            'Chưa có trạng thái mới'),
                                        const SizedBox(height: 16),
                                        const Text(
                                            'Hãy kiểm tra lịch của bạn. Lời nhắc không phải hướng dẫn uống bù.'),
                                        FilledButton(
                                            onPressed: () => Navigator.of(
                                                    context)
                                                .pushNamedAndRemoveUntil(
                                                    AppRoutes.home,
                                                    (_) => false,
                                                    arguments:
                                                        PersonalScheduleEntry
                                                            .open),
                                            child:
                                                const Text('Mở lịch của tôi')),
                                      ]))),
                        for (final item in _items)
                          Card(
                              child: ListTile(
                            leading: Icon(item['is_read'] == true
                                ? Icons.notifications_none
                                : Icons.notifications_active_outlined),
                            title: Text(item['medication_name'] as String),
                            subtitle: Text(
                                'Từ ${item['sender_name'] ?? 'Người thân'} · ${monitorTime(DateTime.parse(item['scheduled_at'] as String))}'),
                            onTap: () {
                              _id = item['id'] as int;
                              unawaited(_load());
                            },
                          )),
                      ]))),
    );
  }
}
