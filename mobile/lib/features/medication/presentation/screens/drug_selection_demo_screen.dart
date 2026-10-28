import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/drug_selection_demo_fixtures.dart';
import '../../domain/entities/medication.dart';
import '../widgets/drug_selection_panel.dart';
import 'drug_selection_screen.dart';

class DrugSelectionDemoScreen extends StatefulWidget {
  const DrugSelectionDemoScreen({super.key});

  @override
  State<DrugSelectionDemoScreen> createState() =>
      _DrugSelectionDemoScreenState();
}

class _DrugSelectionDemoScreenState extends State<DrugSelectionDemoScreen> {
  DrugCatalogItem? _result;

  Future<void> _open(
      DrugSelectionSource source, List<DrugCatalogItem> items) async {
    final result = await showDrugSelectionScreen(context,
        candidates: items,
        source: source,
        search: DrugSelectionDemoFixtures.search);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mẫu · Chọn và xác nhận thuốc')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              'Dữ liệu mẫu tổng hợp, chỉ dùng xem thử. Không quét ảnh hoặc lưu thuốc/lịch. Tìm thủ công: nhập Paracetamol.',
              style: AppTextStyles.body,
            ),
            for (final preset in [
              (
                'OCR · Có kết quả',
                DrugSelectionSource.ocr,
                DrugSelectionDemoFixtures.candidates
              ),
              (
                'OCR · Không có kết quả',
                DrugSelectionSource.ocr,
                const <DrugCatalogItem>[]
              ),
              (
                'Tìm kiếm · Có kết quả',
                DrugSelectionSource.search,
                DrugSelectionDemoFixtures.candidates
              ),
              (
                'Tìm kiếm · Không có kết quả',
                DrugSelectionSource.search,
                const <DrugCatalogItem>[]
              ),
              (
                'Thiếu thông tin',
                DrugSelectionSource.ocr,
                DrugSelectionDemoFixtures.missing
              ),
              (
                'Tên dài và danh sách dài',
                DrugSelectionSource.search,
                DrugSelectionDemoFixtures.longList
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: OutlinedButton(
                  onPressed: () => _open(preset.$2, preset.$3),
                  child: Text(preset.$1),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _result == null
                  ? 'Mẫu · Chưa có lựa chọn được xác nhận'
                  : 'Mẫu · Đã xác nhận: ${_result!.name} · ${_result!.strength} · ${_result!.id}',
              key: const ValueKey('demo-result'),
              style: AppTextStyles.bodyStrong,
            ),
          ],
        ),
      );
}
