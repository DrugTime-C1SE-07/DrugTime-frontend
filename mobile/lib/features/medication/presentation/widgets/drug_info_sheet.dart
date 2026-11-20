import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import '../state/medication_controller.dart';
import 'dosage_form_icon.dart';
import 'medication_labels.dart';

/// Mở S07-M2i "Thông tin thuốc" cho [drug] (bước thêm thuốc).
Future<void> showDrugInfoSheet(BuildContext context, DrugCatalogItem drug) =>
    _show(context, DrugCatalogDetail(
      id: drug.id,
      name: drug.name,
      activeIngredient: _orNull(drug.activeIngredient),
      strength: _orNull(drug.strength),
      dosageForm: _orNull(drug.dosageForm),
    ));

/// Mở S07-M2i cho một thuốc đang dùng.
Future<void> showMedicationInfoSheet(BuildContext context, Medication medication) =>
    _show(context, DrugCatalogDetail(
      id: medication.catalogId,
      name: medication.name,
      activeIngredient: _orNull(medication.activeIngredient),
      strength: _orNull(medication.strength),
      dosageForm: _orNull(medication.dosageForm),
    ));

String? _orNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

Future<void> _show(BuildContext context, DrugCatalogDetail known) {
  final controller = MedicationScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => DrugInfoSheet(
      known: known,
      load: () => controller.fetchCatalogDetail(known.id),
    ),
  );
}

/// S07-M2i: thông tin chính thức trong danh mục, chỉ đọc. Hiện ngay phần đã có ([known]), rồi
/// bổ sung nhà sản xuất, nước sản xuất, quy cách và nguồn khi [load] trả về. Trường không có
/// dữ liệu ghi "Chưa có thông tin". Không có công dụng, liều tối đa hay cảnh báo: danh mục
/// chưa có nguồn được duyệt cho các mục này (Q1 của 01-requirement).
class DrugInfoSheet extends StatefulWidget {
  const DrugInfoSheet({super.key, required this.known, required this.load});

  final DrugCatalogDetail known;
  final Future<DrugCatalogDetail> Function() load;

  @override
  State<DrugInfoSheet> createState() => _DrugInfoSheetState();
}

class _DrugInfoSheetState extends State<DrugInfoSheet> {
  DrugCatalogDetail? _detail;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final detail = await widget.load();
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on Object {
      // Lỗi mạng hay 404: vẫn giữ phần đã có, báo và cho thử lại.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final known = widget.known;
    final d = _detail;
    String? pick(String? Function(DrugCatalogDetail) f) =>
        _orNull(d == null ? f(known) : f(d) ?? f(known));
    final strength = pick((x) => x.strength);
    final form = pick((x) => x.dosageForm);
    final source = sourceLabel(d?.source);

    final rows = <(String, String?)>[
      ('Hoạt chất', pick((x) => x.activeIngredient)),
      ('Hàm lượng', strength == null ? null : formatStrength(strength)),
      ('Dạng bào chế', form),
      ('Nhà sản xuất', d?.manufacturerName),
      ('Nước sản xuất', d?.manufacturerCountry),
      ('Quy cách', d?.packagingSpec),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('drug-info-sheet'),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              DosageFormTile(dosageForm: form),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(d?.name ?? known.name, style: AppTextStyles.title),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(LucideIcons.x),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(children: [
                for (final (i, (label, value)) in rows.indexed)
                  _InfoRow(
                    label: label,
                    // Trường chỉ server có: đang tải thì chưa kết luận là thiếu.
                    value: value,
                    pending: _loading && i >= 3,
                    last: i == rows.length - 1,
                  ),
              ]),
            ),
            if (_failed) ...[
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                const Icon(LucideIcons.wifiOff, size: 18, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('Chưa tải được thông tin nhà sản xuất',
                      style: AppTextStyles.body),
                ),
                TextButton(onPressed: _fetch, child: const Text('Thử lại')),
              ]),
            ],
            if (source != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Nguồn: $source',
                  style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.pending,
    required this.last,
  });

  final String label;
  final String? value;
  final bool pending;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = value ?? (pending ? 'Đang tải…' : 'Chưa có thông tin');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Semantics(
        label: '$label: $text',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: AppTextStyles.body.copyWith(color: AppColors.inkMuted)),
            ),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.end,
                style: value == null
                    ? AppTextStyles.body.copyWith(color: AppColors.inkMuted)
                    : AppTextStyles.bodyStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
