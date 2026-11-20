import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';

class ShareAndLinkScreen extends StatelessWidget {
  const ShareAndLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget option(String title, String description, IconData icon, String route,
            Key key) =>
        Card(
          elevation: 0,
          child: ListTile(
            key: key,
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
                backgroundColor: AppColors.brandTint,
                child: Icon(icon, color: AppColors.brand)),
            title: Text(title, style: AppTextStyles.bodyStrong),
            subtitle: Text(description, style: AppTextStyles.caption),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(route),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Mời người thân')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
            'Chọn cách kết nối. Người thân cần cài DrugTime để tiếp tục.'),
        const SizedBox(height: 14),
        option(
            'Hiện mã QR của bạn',
            'Để người thân quét mã của bạn trong DrugTime.',
            Icons.qr_code_2,
            AppRoutes.familyMyCode,
            const Key('share-own-qr')),
        const SizedBox(height: 8),
        option(
            'Quét mã QR người thân',
            'Dùng camera để quét mã do người thân mở.',
            Icons.qr_code_scanner,
            AppRoutes.familyScanCode,
            const Key('share-scan-qr')),
        const SizedBox(height: 8),
        option(
            'Gửi link mời',
            'Gửi qua Zalo, SMS hoặc email.',
            Icons.share_outlined,
            AppRoutes.familyShareLink,
            const Key('share-invite-link')),
        const SizedBox(height: 14),
        const Card(
            color: AppColors.brandTint,
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Người thân chỉ có quyền xem thông tin được chia sẻ sau khi bạn xác nhận.')),
                    ]))),
      ])),
    );
  }
}
