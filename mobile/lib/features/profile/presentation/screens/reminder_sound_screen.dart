import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

class ReminderSoundScreen extends StatelessWidget {
  const ReminderSoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: profileFlowCanvas,
        appBar: ProfileFlowHeader('Âm thanh nhắc nhở',
            titleScale: MediaQuery.textScalerOf(context).scale(18) / 18),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
              const ProfileUnavailable(
                  message: 'Chọn và nghe thử âm thanh chưa khả dụng.'),
              const SizedBox(height: 16),
              const ProfileFlowCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('Âm lượng nhắc nhở', style: AppTextStyles.bodyStrong),
                    Text('Chưa khả dụng', style: AppTextStyles.caption),
                    Slider(value: 0, onChanged: null),
                  ])),
              const SizedBox(height: 20),
              ProfileFlowSection('Chọn âm thanh', children: [
                for (final sound in const [
                  'Chuông mặc định',
                  'Nhẹ nhàng',
                  'Âm cha hữu ơi',
                  'Khẩn cấp',
                  'Chuông điện thoại mặc định',
                  'Im lặng (chỉ rung)'
                ])
                  ProfileFlowRow(sound,
                      icon: Icons.play_circle_outline,
                      unavailable: true,
                      trailing: const Icon(Icons.radio_button_unchecked,
                          size: 20, color: AppColors.inkDisabled)),
              ]),
            ])),
      );
}
