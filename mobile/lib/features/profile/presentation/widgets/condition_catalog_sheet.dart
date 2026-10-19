import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../state/profile_controller.dart';
import 'profile_notices.dart';

Future<void> showConditionCatalog(BuildContext context) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const ConditionCatalogSheet());

class ConditionCatalogSheet extends StatefulWidget {
  const ConditionCatalogSheet({super.key});
  @override
  State<ConditionCatalogSheet> createState() => _ConditionCatalogSheetState();
}

class _ConditionCatalogSheetState extends State<ConditionCatalogSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ProfileScope.read(context).loadCatalog(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: [
              Row(children: [
                const Expanded(
                    child: Text('Thêm bệnh nền', style: AppTextStyles.heading)),
                IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              Expanded(
                  child: ListView(children: [
                const ProfileNotices(),
                if (!c.denied) ...[
                  if (c.catalogItems.isEmpty &&
                      !c.catalogLoading &&
                      c.catalogError == null)
                    const Text('Danh mục chưa có bệnh để chọn.'),
                  for (final item in c.catalogItems)
                    ListTile(
                      title: Text(item.name),
                      trailing: c.profile?.conditions
                                  .any((e) => e.conditionId == item.id) ==
                              true
                          ? const Text('Đã thêm')
                          : const Icon(Icons.add),
                      enabled: !c.saving &&
                          !c.loading &&
                          c.profile?.conditions
                                  .any((e) => e.conditionId == item.id) !=
                              true,
                      onTap: () async {
                        final ok = await c.addCondition(item.id);
                        if (context.mounted && ok) Navigator.pop(context);
                      },
                    ),
                  if (c.catalogLoading) const LinearProgressIndicator(),
                  if (c.catalogError != null) Text(c.catalogError!.message),
                  if (c.hasMore || c.catalogError != null)
                    TextButton(
                        onPressed: c.catalogLoading || c.saving
                            ? null
                            : () => c.loadCatalog(),
                        child: Text(c.catalogError == null
                            ? 'Xem thêm'
                            : 'Thử lại danh mục')),
                ],
              ])),
            ])));
  }
}
