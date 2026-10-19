import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/two_column_grid.dart';
import '../state/profile_controller.dart';
import '../widgets/condition_catalog_sheet.dart';
import '../widgets/condition_editor_sheet.dart';
import '../widgets/profile_icons.dart';
import '../widgets/profile_notices.dart';

class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});
  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ProfileScope.read(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Thông tin y tế'),
          leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              icon: const ProfileIcon('p-arrow-left'))),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const ProfileNotices(),
                    if (c.loading && c.profile == null) const ProfileLoading(),
                    if (c.profile != null && !c.denied) ...[
                      const Text('BỆNH MÃN TÍNH / BỆNH NỀN',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 16),
                      if (c.profile!.conditions.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                                'Bạn chưa thêm bệnh nền. Chọn từ danh mục để cập nhật hồ sơ.')),
                      TwoColumnGrid(children: [
                        for (final item in c.profile!.conditions)
                          FilledButton(
                            onPressed: c.saving
                                ? null
                                : () => showConditionEditor(context, item),
                            style: FilledButton.styleFrom(
                                shape: const StadiumBorder()),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(children: [
                                  const ProfileIcon('m-check'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(item.name,
                                          textAlign: TextAlign.center))
                                ])),
                          )
                      ]),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: c.saving || c.loading
                              ? null
                              : () => showConditionCatalog(context),
                          child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ProfileIcon('m-plus'),
                                    SizedBox(width: 8),
                                    Flexible(child: Text('Thêm bệnh khác'))
                                  ]))),
                      const SizedBox(height: 16),
                      const Text(
                          'Nhấn vào bệnh đã thêm để sửa phân loại, giai đoạn hoặc xóa khỏi hồ sơ.',
                          style: AppTextStyles.caption),
                    ],
                  ]))),
    );
  }
}
