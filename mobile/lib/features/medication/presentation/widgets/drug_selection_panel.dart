import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import 'medication_labels.dart';

enum DrugSelectionSource { ocr, search }

/// Local selection only. The caller owns any subsequent schedule or save.
class DrugSelectionPanel extends StatefulWidget {
  const DrugSelectionPanel({
    super.key,
    required this.candidates,
    required this.source,
    required this.onConfirm,
    required this.onManualSearch,
    this.isInUse,
  });

  final List<DrugCatalogItem> candidates;
  final DrugSelectionSource source;
  final ValueChanged<DrugCatalogItem> onConfirm;
  final VoidCallback onManualSearch;
  final bool Function(String)? isInUse;

  @override
  State<DrugSelectionPanel> createState() => _DrugSelectionPanelState();
}

class _DrugSelectionPanelState extends State<DrugSelectionPanel> {
  DrugCatalogItem? _selected;
  bool _confirmed = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _select(DrugCatalogItem item) {
    setState(() => _selected = item);
    // Bring the read-only review into view after choosing a distant result.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void didUpdateWidget(DrugSelectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.candidates, widget.candidates) ||
        oldWidget.source != widget.source) {
      _selected = null;
    }
  }

  void _confirm() {
    final selected = _selected;
    if (_confirmed ||
        selected == null ||
        !widget.candidates.any((item) => identical(item, selected))) {
      return;
    }
    setState(() => _confirmed = true);
    widget.onConfirm(selected);
  }

  String _known(String value) =>
      value.trim().isEmpty ? 'Chưa có thông tin' : value;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final empty = widget.candidates.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                widget.source == DrugSelectionSource.ocr
                    ? 'Kết quả từ OCR'
                    : 'Kết quả tìm kiếm',
                style: AppTextStyles.captionStrong,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (empty) ...[
                const Icon(Icons.search_off,
                    size: 48, color: AppColors.inkMuted),
                const SizedBox(height: AppSpacing.md),
                const Text('Không tìm thấy thuốc phù hợp',
                    style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Kiểm tra lại chính tả, hoặc thử tìm bằng tên hoạt chất (ví dụ: Paracetamol).',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: widget.onManualSearch,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.tapTarget)),
                  child: const Text('Tìm kiếm thủ công',
                      textAlign: TextAlign.center),
                ),
              ] else ...[
                const Text('Chọn đúng thuốc, rồi kiểm tra trước khi xác nhận.',
                    style: AppTextStyles.body),
                if (selected != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    key: const ValueKey('drug-selection-review'),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thông tin thuốc đã chọn',
                            style: AppTextStyles.heading),
                        for (final field in [
                          ('Tên thuốc', selected.name),
                          ('Hoạt chất', selected.activeIngredient),
                          ('Hàm lượng', selected.strength),
                          ('Dạng bào chế', selected.dosageForm),
                          ('Đơn vị', selected.unit),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text('${field.$1}: ${_known(field.$2)}',
                                style: AppTextStyles.body),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Chạm thuốc khác bên dưới để đổi lựa chọn.',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < widget.candidates.length; i++)
                  _candidate(widget.candidates[i], i),
              ],
            ],
          ),
        ),
        if (!empty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: FilledButton(
                onPressed: selected == null || _confirmed ? null : _confirm,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.primaryButton)),
                child:
                    const Text('Xác nhận thuốc', textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    );
  }

  Widget _candidate(DrugCatalogItem item, int index) {
    final selected = identical(_selected, item);
    return Semantics(
      selected: selected,
      button: true,
      enabled: !_confirmed,
      label: 'Chọn ${item.name}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: selected ? AppColors.brandTint : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
            side: BorderSide(
                color: selected ? AppColors.brand : AppColors.border,
                width: selected ? 2 : 1),
          ),
          child: InkWell(
            key: ValueKey('drug-candidate-$index'),
            borderRadius: BorderRadius.circular(AppRadius.field),
            onTap: _confirmed ? null : () => _select(item),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: AppTextStyles.bodyStrong),
                          if (item.strength.trim().isNotEmpty)
                            Text(item.strength, style: AppTextStyles.caption),
                          Text(
                              drugSubtitle(
                                  item.activeIngredient, item.dosageForm),
                              style: AppTextStyles.caption),
                          if (item.unit.trim().isNotEmpty)
                            Text('Đơn vị: ${item.unit}',
                                style: AppTextStyles.caption),
                          if (widget.isInUse?.call(item.id) ?? false)
                            const Text('Đang dùng',
                                style: AppTextStyles.captionStrong),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
