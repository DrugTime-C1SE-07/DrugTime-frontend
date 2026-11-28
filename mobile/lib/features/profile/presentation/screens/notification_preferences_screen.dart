import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/notification/notification_preferences.dart';
import '../../../../core/notification/reminder_sound.dart';
import '../../../../core/notification/reminder_sound_controller.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../../../medication/presentation/widgets/medication_form_fields.dart';

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

  Future<void> _confirmDiscardAndPop() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ các thay đổi?'),
        content: const Text(
          'Các tùy chọn thông báo vừa sửa chưa được lưu. Bạn có chắc muốn quay lại?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tiếp tục chỉnh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      final controller = _controller;
      if (controller != null) {
        setState(() {
          _reminders = controller.reminders;
          _familyAlerts = controller.familyAlertsEnabled;
        });
      }
      Navigator.of(context).pop();
    }
  }

  // Đọc bản nháp lúc bấm, không dùng bản chụp lúc build: hai lần bấm liền nhau không đè nhau.
  void _edit(ReminderPreferences Function(ReminderPreferences) change) =>
      setState(() => _reminders = change(_reminders!));

  Widget _toggle(
      String title, IconData icon, bool? value, ValueChanged<bool>? onChanged,
      {String? subtitle}) {
    final available = value != null;
    return ProfileFlowRow(title,
        icon: icon,
        subtitle: subtitle,
        unavailable: !available,
        trailing: Switch(
            value: value ?? false,
            onChanged: _saving || !available ? null : onChanged));
  }

  List<Widget> _caregiverRows() {
    final controller = _controller;
    if (controller == null) {
      return [
        _toggle('Báo người giám sát khi bỏ lỡ liều', Icons.people_outline, null,
            null),
      ];
    }
    if (!controller.supportsFamilyAlerts) {
      return [
        ProfileFlowRow(
          'Báo người giám sát khi bỏ lỡ liều',
          icon: Icons.people_outline,
          subtitle: 'Quản lý tại Người giám sát',
          onTap: () => Navigator.pushNamed(context, AppRoutes.caregivers),
        ),
      ];
    }
    final Widget switchRow;
    if (_loadingFamily && _familyAlerts == null) {
      switchRow = const ProfileFlowRow('Báo người giám sát khi bỏ lỡ liều',
          icon: Icons.people_outline,
          trailing: SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_familyLoadFailed && _familyAlerts == null) {
      switchRow = ProfileFlowRow('Báo người giám sát khi bỏ lỡ liều',
          icon: Icons.people_outline,
          onTap: _loadFamilyAlerts,
          trailing: const Text('Thử lại'));
    } else {
      switchRow = _toggle(
          'Báo người giám sát khi bỏ lỡ liều',
          Icons.people_outline,
          _familyAlerts,
          (v) => setState(() => _familyAlerts = v));
    }
    return [
      switchRow,
      ProfileFlowRow(
        'Quản lý người giám sát',
        icon: Icons.manage_accounts_outlined,
        subtitle: 'Xem và tùy chỉnh liên kết người thân',
        onTap: () => Navigator.pushNamed(context, AppRoutes.caregivers),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _reminders;
    final on = reminders?.enabled ?? false;
    final soundController = ReminderSoundScope.maybeOf(context);
    final selectedSound = soundController?.selected;
    final silentNoVibrate = reminders != null &&
        on &&
        selectedSound?.kind == ReminderSoundKind.silent &&
        !reminders.vibrate;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscardAndPop());
      },
      child: Scaffold(
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
              if (silentNoVibrate) ...[
                const CautionNote(
                  text:
                      'Đang chọn âm Im lặng và tắt rung: thông báo nhắc thuốc sẽ không kêu và không rung.',
                ),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selectedSound != null) ...[
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 128),
                            child: Text(
                              selectedSound.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.inkMuted),
                      ],
                    ),
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.profileReminderSound,
                        arguments: _reminders?.vibrate)),
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
                if (reminders != null) ...[
                  const ProfileFlowRow(
                    'Cảnh báo tương tác thuốc',
                    icon: Icons.warning_amber_outlined,
                    subtitle: 'Luôn bật để bảo đảm an toàn dùng thuốc',
                    trailing: Switch(value: true, onChanged: null),
                  ),
                  _toggle(
                    'Sắp hết thuốc',
                    Icons.inventory_2_outlined,
                    reminders.lowStockAlerts,
                    (v) => _edit((r) => r.copyWith(lowStockAlerts: v)),
                  ),
                ] else ...[
                  _toggle('Cảnh báo tương tác thuốc',
                      Icons.warning_amber_outlined, null, null),
                  _toggle(
                      'Sắp hết thuốc', Icons.inventory_2_outlined, null, null),
                ],
              ]),
              ProfileFlowSection('Người giám sát', children: _caregiverRows()),
              ProfileFlowSection('Thông báo khác', children: [
                if (reminders != null) ...[
                  const ProfileFlowRow(
                    'Nhắc lịch tái khám',
                    icon: Icons.calendar_today_outlined,
                    unavailable: true,
                  ),
                  const ProfileFlowRow(
                    'Cập nhật ứng dụng',
                    icon: Icons.update,
                    unavailable: true,
                  ),
                ] else ...[
                  _toggle('Nhắc lịch tái khám', Icons.calendar_today_outlined,
                      null, null),
                  _toggle('Cập nhật ứng dụng', Icons.update, null, null),
                ],
              ]),
              ProfileFlowButton(
                  label: _saving ? 'Đang lưu…' : 'Lưu thay đổi',
                  onPressed: _dirty && !_saving ? _save : null),
            ])),
      ),
    );
  }
}
