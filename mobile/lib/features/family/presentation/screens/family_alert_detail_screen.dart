import 'package:flutter/material.dart';
import '../state/family_alert_scope.dart';

class FamilyAlertDetailScreen extends StatefulWidget {
  const FamilyAlertDetailScreen({super.key, required this.id});
  final int id;
  @override
  State<FamilyAlertDetailScreen> createState() =>
      _FamilyAlertDetailScreenState();
}

class _FamilyAlertDetailScreenState extends State<FamilyAlertDetailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FamilyAlertScope.read(context).open(widget.id);
    });
  }

  @override
  // Resume đọc lại qua API để quyền bị thu hồi có hiệu lực ở request kế tiếp.
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FamilyAlertScope.read(context).open(widget.id);
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
    // Controller dùng chung; chỉ dựng nội dung khớp ID của route hiện tại.
    final item = controller.detail?.id == widget.id ? controller.detail : null;
    return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết cảnh báo')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (controller.loading) const LinearProgressIndicator(),
          if (controller.error != null) ...[
            Text(controller.error!.message),
            TextButton(
                onPressed: () => controller.open(widget.id),
                child: const Text('Thử lại')),
          ],
          if (item != null) ...[
            Text(item.patientName ?? 'Người thân',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(item.content),
            const SizedBox(height: 16),
            if (item.isLegacy)
              const Text('Không có dữ liệu liều cũ')
            else ...[
              Text(item.medicationName!),
              Text(item.scheduledTimeVietnam),
            ],
            const SizedBox(height: 24),
            FilledButton(
                onPressed: item.isRead || controller.saving
                    ? null
                    : controller.markRead,
                child: Text(controller.saving
                    ? 'Đang lưu…'
                    : item.isRead
                        ? 'Đã đọc'
                        : 'Đánh dấu đã đọc')),
          ],
        ]));
  }
}
