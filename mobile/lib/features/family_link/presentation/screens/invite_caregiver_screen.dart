import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

class InviteCaregiverScreen extends StatelessWidget {
  const InviteCaregiverScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: ProfileFlowHeader('Mời người thân',
            titleScale: MediaQuery.textScalerOf(context).scale(18) / 18,
            backgroundColor: AppColors.canvas),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
              const Text(
                  'Chọn cách kết nối. Người thân cần cài DrugTime để tiếp tục.',
                  style: AppTextStyles.caption),
              const SizedBox(height: 20),
              _option(
                  context,
                  'Hiện mã QR của bạn',
                  'Để người thân quét mã của bạn trong DrugTime.',
                  Icons.qr_code,
                  AppRoutes.familyMyCode,
                  AppColors.brandTint,
                  AppColors.brand),
              _option(
                  context,
                  'Quét mã QR người thân',
                  'Dùng camera để quét mã do người thân mở.',
                  Icons.photo_camera_outlined,
                  AppRoutes.familyScanCode,
                  AppColors.infoBg,
                  AppColors.info),
              _option(
                  context,
                  'Gửi link mời',
                  'Gửi qua ứng dụng chia sẻ trên điện thoại.',
                  Icons.link,
                  AppRoutes.familyShareLink,
                  const Color(0xFFEEE9FA),
                  const Color(0xFF604497)),
              const ProfileFlowCard(
                  shadow: false,
                  color: Color(0xFFEEF3F1),
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Người thân chỉ có quyền xem dữ liệu được chia sẻ sau khi bạn xác nhận và bật chia sẻ.',
                      style: AppTextStyles.caption)),
            ])),
      );
  Widget _option(BuildContext context, String title, String subtitle,
          IconData icon, String route, Color tint, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ProfileFlowCard(
            padding: EdgeInsets.zero,
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamed(context, route),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: tint,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: color, size: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title, style: AppTextStyles.bodyStrong),
                              const SizedBox(height: 2),
                              Text(subtitle, style: AppTextStyles.caption),
                            ])),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.inkMuted),
                      ])),
                ))),
      );
}
