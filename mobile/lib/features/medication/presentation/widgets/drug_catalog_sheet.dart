import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import 'medication_error_messages.dart';
import 'medication_labels.dart';

/// Chờ người dùng ngừng gõ ngần này rồi mới gọi API tìm danh mục.
const catalogSearchDebounce = Duration(milliseconds: 300);

Future<DrugCatalogItem?> showDrugCatalogSheet(BuildContext context) {
  return showModalBottomSheet<DrugCatalogItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const DrugCatalogSheet(),
  );
}

/// Tìm & chọn thuốc từ danh mục chuẩn (S06a).
class DrugCatalogSheet extends StatefulWidget {
  const DrugCatalogSheet({super.key});

  @override
  State<DrugCatalogSheet> createState() => _DrugCatalogSheetState();
}

class _DrugCatalogSheetState extends State<DrugCatalogSheet> {
  late final MedicationController _controller;
  Timer? _debounce;

  /// `null` khi đang tìm.
  List<DrugCatalogItem>? _results = const [];
  MedicationFailure? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = MedicationScope.read(context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    setState(() => _results = null);
    _debounce = Timer(catalogSearchDebounce, () => _search(value));
  }

  Future<void> _search(String query) async {
    List<DrugCatalogItem> results;
    MedicationFailure? error;
    try {
      results = await _controller.searchCatalog(query);
    } on MedicationFailure catch (failure) {
      results = const [];
      error = failure;
    }
    // Kết quả của chuỗi cũ về muộn hơn chuỗi mới thì bỏ.
    if (!mounted || query != _query) return;
    setState(() {
      _results = results;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: const Text('Chọn thuốc từ danh mục', style: AppTextStyles.heading),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    autofocus: true,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tên thuốc hoặc hoạt chất',
                      prefixIcon: Icon(Icons.search, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: results == null
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _SheetMessage(
                          icon: Icons.cloud_off_outlined,
                          title: 'Chưa tìm được',
                          message: medicationErrorMessage(_error!),
                        )
                      : _query.trim().isEmpty
                          ? const _SheetMessage(
                              icon: Icons.search,
                              title: 'Nhập tên thuốc hoặc hoạt chất',
                              message: 'Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.',
                            )
                          : results.isEmpty
                              ? const _NoResults()
                              : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: AppSpacing.page + 48 + AppSpacing.md,
                          ),
                          itemBuilder: (context, i) => _CatalogTile(
                            drug: results[i],
                            inUse: _controller.isInUse(results[i].id),
                            onTap: () => Navigator.of(context).pop(results[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.drug, required this.inUse, required this.onTap});

  final DrugCatalogItem drug;
  final bool inUse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const PillTile(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drug.name, style: AppTextStyles.bodyStrong),
                  Text(
                    drugSubtitle(drug.activeIngredient, drug.dosageForm),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (inUse) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text(
                  'Đang dùng',
                  style: AppTextStyles.captionStrong.copyWith(color: AppColors.brand),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(height: AppSpacing.xl),
          Icon(Icons.search_off, size: 48, color: AppColors.inkMuted),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Không tìm thấy thuốc phù hợp',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Kiểm tra lại chính tả, hoặc thử tìm bằng tên hoạt chất (ví dụ: Paracetamol).',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(icon, size: 48, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
