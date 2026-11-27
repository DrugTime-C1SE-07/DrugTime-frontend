import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../core/notification/notification_preferences.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  NotificationPreferencesController? _controller;

  /// Bản nháp đang chỉnh; chỉ ghi khi bấm "Lưu thay đổi".
  ReminderPreferences? _reminders;
  bool? _familyAlerts;
  bool _loadingFamily = false;
  bool _familyLoadFailed = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = NotificationPreferencesScope.maybeOf(context);
    if (controller == null || identical(controller, _controller)) return;
    _controller = controller;
    _reminders = controller.reminders;
    _familyAlerts = controller.familyAlertsEnabled;
    unawaited(_loadFamilyAlerts());
  }

  Future<void> _loadFamilyAlerts() async {
    final controller = _controller;
    if (controller == null || !controller.supportsFamilyAlerts) return;
    setState(() {
      _loadingFamily = true;
      _familyLoadFailed = false;
    });
    try {
      await controller.loadFamilyAlerts();
      if (!mounted) return;
      setState(() => _familyAlerts = controller.familyAlertsEnabled);
    } on Exception {
      if (mounted) setState(() => _familyLoadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  bool get _dirty {
    final controller = _controller;
    if (controller == null) return false;
    return _reminders != controller.reminders ||
        (_familyAlerts != null &&
            _familyAlerts != controller.familyAlertsEnabled);
  }

  Future<void> _save() async {
    final controller = _controller!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await controller.save(
          reminders: _reminders!, familyAlertsEnabled: _familyAlerts);
      messenger.showSnackBar(
          const SnackBar(content: Text('Đã lưu tùy chọn thông báo.')));
    } on Exception {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Chưa lưu được tùy chọn báo người giám sát. Vui lòng thử lại.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Đọc bản nháp lúc bấm, không dùng bản chụp lúc build: hai lần bấm liền nhau không đè nhau.
  void _edit(ReminderPreferences Function(ReminderPreferences) change) =>
      setState(() => _reminders = change(_reminders!));

  Widget _toggle(
      String title, IconData icon, bool? value, ValueChanged<bool>? onChanged) {
    final available = value != null;
    return ProfileFlowRow(title,
        icon: icon,
        unavailable: !available,
        trailing: Switch(
            value: value ?? false,
            onChanged: _saving || !available ? null : onChanged));
  }

  Widget _familyRow() {
    if (_loadingFamily && _familyAlerts == null) {
      return const ProfileFlowRow('Báo người giám sát khi bỏ lỡ liều',
          icon: Icons.people_outline,
          trailing: SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_familyLoadFailed && _familyAlerts == null) {
      return ProfileFlowRow('Báo người giám sát khi bỏ lỡ liều',
          icon: Icons.people_outline,
          onTap: _loadFamilyAlerts,
          trailing: const Text('Thử lại'));
    }
    return _toggle('Báo người giám sát khi bỏ lỡ liều', Icons.people_outline,
        _familyAlerts, (v) => setState(() => _familyAlerts = v));
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _reminders;
    final on = reminders?.enabled ?? false;
    return Scaffold(
      backgroundColor: profileFlowCanvas,
      appBar: ProfileFlowHeader('Thông báo & Nhắc nhở',
          titleScale: MediaQuery.textScalerOf(context).scale(18) / 18),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
            if (reminders == null) ...[
              const ProfileUnavailable(
                  message:
                      'Các tùy chọn thông báo chưa khả dụng. Lịch nhắc hiện tại vẫn được giữ nguyên.'),
              const SizedBox(height: 16),
            ] else if (!on) ...[
              const ProfileUnavailable(
                  message:
                      'Nhắc uống thuốc đang tắt: máy sẽ không báo khi đến giờ uống. Lịch uống vẫn được giữ nguyên.'),
              const SizedBox(height: 16),
            ],
            ProfileFlowSection('Nhắc uống thuốc', children: [
              _toggle(
                  'Bật nhắc nhở',
                  Icons.notifications_none,
                  reminders?.enabled,
                  (v) => _edit((r) => r.copyWith(enabled: v))),
              ProfileFlowRow('Âm thanh nhắc nhở',
                  icon: Icons.volume_up_outlined,
                  onTap: () => Navigator.pushNamed(
                      context, AppRoutes.profileReminderSound)),
              _toggle('Rung khi nhắc nhở', Icons.vibration, reminders?.vibrate,
                  on ? (v) => _edit((r) => r.copyWith(vibrate: v)) : null),
              _toggle(
                  'Nhắc lại nếu bỏ lỡ liều',
                  Icons.repeat,
                  reminders?.repeatIfMissed,
                  on
                      ? (v) => _edit((r) => r.copyWith(repeatIfMissed: v))
                      : null),
            ]),
            ProfileFlowSection('Cảnh báo', children: [
              _toggle('Cảnh báo tương tác thuốc', Icons.warning_amber_outlined,
                  null, null),
              _toggle('Sắp hết thuốc', Icons.inventory_2_outlined, null, null),
            ]),
            ProfileFlowSection('Người giám sát', children: [_familyRow()]),
            ProfileFlowSection('Thông báo khác', children: [
              _toggle('Nhắc lịch tái khám', Icons.calendar_today_outlined, null,
                  null),
              _toggle('Cập nhật ứng dụng', Icons.update, null, null),
            ]),
            ProfileFlowButton(
                label: _saving ? 'Đang lưu…' : 'Lưu thay đổi',
                onPressed: _dirty && !_saving ? _save : null),
          ])),
    );
  }
}
