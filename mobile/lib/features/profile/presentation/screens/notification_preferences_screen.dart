import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});
  Widget _toggle(String title, IconData icon) => ProfileFlowRow(title,
      icon: icon,
      unavailable: true,
      trailing: const Switch(value: false, onChanged: null));
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: profileFlowCanvas,
        appBar: ProfileFlowHeader('Thông báo & Nhắc nhở',
            titleScale: MediaQuery.textScalerOf(context).scale(18) / 18),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
              const ProfileUnavailable(
                  message:
                      'Các tùy chọn thông báo chưa khả dụng. Lịch nhắc hiện tại vẫn được giữ nguyên.'),
              const SizedBox(height: 16),
              ProfileFlowSection('Nhắc uống thuốc', children: [
                _toggle('Bật nhắc nhở', Icons.notifications_none),
                ProfileFlowRow('Âm thanh nhắc nhở',
                    icon: Icons.volume_up_outlined,
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.profileReminderSound)),
                _toggle('Rung khi nhắc nhở', Icons.vibration),
                _toggle('Nhắc lại nếu bỏ lỡ liều', Icons.repeat),
              ]),
              ProfileFlowSection('Cảnh báo', children: [
                _toggle(
                    'Cảnh báo tương tác thuốc', Icons.warning_amber_outlined),
                _toggle('Sắp hết thuốc', Icons.inventory_2_outlined),
              ]),
              ProfileFlowSection('Người giám sát', children: [
                _toggle(
                    'Báo người giám sát khi bỏ lỡ liều', Icons.people_outline)
              ]),
              ProfileFlowSection('Thông báo khác', children: [
                _toggle('Nhắc lịch tái khám', Icons.calendar_today_outlined),
                _toggle('Cập nhật ứng dụng', Icons.update),
              ]),
              const ProfileFlowButton(label: 'Lưu thay đổi'),
            ])),
      );
}
