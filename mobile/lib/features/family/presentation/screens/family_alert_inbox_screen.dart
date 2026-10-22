import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../state/family_alert_scope.dart';

class FamilyAlertInboxScreen extends StatefulWidget {
  const FamilyAlertInboxScreen({super.key});
  @override
  State<FamilyAlertInboxScreen> createState() => _FamilyAlertInboxScreenState();
}

class _FamilyAlertInboxScreenState extends State<FamilyAlertInboxScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FamilyAlertScope.read(context).load();
    });
  }

  @override
  // Chỉ tải lại inbox đang hiện khi resume để lấy quyền và badge mới từ server.
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      FamilyAlertScope.read(context).load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = FamilyAlertScope.of(context);
    return Scaffold(
        appBar: AppBar(title: const Text('Cảnh báo người thân')),
        body: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (Theme.of(context).platform == TargetPlatform.iOS)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('Thông báo đẩy chưa được hỗ trợ')),
                if (controller.loading) const LinearProgressIndicator(),
                if (controller.error != null) ...[
                  Text(controller.error!.message),
                  TextButton(
                      onPressed: controller.load, child: const Text('Thử lại')),
                ],
                if (!controller.loading &&
                    controller.error == null &&
                    controller.items.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chưa có cảnh báo')),
                for (final item in controller.items)
                  Card(
                      child: ListTile(
                    leading: Icon(item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active),
                    title: Text(item.patientName ?? 'Người thân'),
                    subtitle: Text(item.isLegacy
                        ? 'Không có dữ liệu liều cũ'
                        : '${item.medicationName}\n${item.scheduledTimeVietnam}'),
                    trailing: Text(item.isRead ? 'Đã đọc' : 'Chưa đọc'),
                    onTap: () async {
                      await Navigator.pushNamed(
                          context, AppRoutes.familyAlertDetail,
                          arguments: item.id);
                      // Detail có thể đã PATCH đọc; nạp lại danh sách và count.
                      if (mounted) await controller.load();
                    },
                  )),
                if (controller.items.length < controller.total)
                  TextButton(
                      onPressed: controller.loading
                          ? null
                          : () => controller.load(more: true),
                      child: const Text('Xem thêm')),
              ],
            )));
  }
}
