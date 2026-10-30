import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import 'medication_error_messages.dart';
import 'drug_selection_panel.dart';

/// Chờ người dùng ngừng gõ ngần này rồi mới gọi API tìm danh mục.
const catalogSearchDebounce = Duration(milliseconds: 300);

typedef CatalogSearch = Future<List<DrugCatalogItem>> Function(String query);

Future<DrugCatalogItem?> showDrugCatalogSheet(BuildContext context,
    {CatalogSearch? search, bool Function(String)? isInUse}) {
  return showModalBottomSheet<DrugCatalogItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: DrugCatalogSheet(search: search, isInUse: isInUse),
      ),
    ),
  );
}

/// Tìm & chọn thuốc từ danh mục chuẩn (S06a).
class DrugCatalogSheet extends StatefulWidget {
  const DrugCatalogSheet({super.key, this.search, this.isInUse});

  final CatalogSearch? search;
  final bool Function(String)? isInUse;

  @override
  State<DrugCatalogSheet> createState() => _DrugCatalogSheetState();
}

class _DrugCatalogSheetState extends State<DrugCatalogSheet> {
  late final CatalogSearch _searchCatalog;
  late final bool Function(String) _isInUse;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  /// `null` khi đang tìm.
  List<DrugCatalogItem>? _results = const [];
  MedicationFailure? _error;
  String _query = '';
  int _generation = 0;
  bool _tooLong = false;

  @override
  void initState() {
    super.initState();
    final controller = widget.search == null || widget.isInUse == null
        ? MedicationScope.read(context)
        : null;
    _searchCatalog = widget.search ?? controller!.searchCatalog;
    _isInUse = widget.isInUse ?? controller!.isInUse;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value.trim();
    final generation = ++_generation;
    _debounce?.cancel();
    _tooLong = _query.runes.length > 100;
    setState(() {
      _error = null;
      _results = _query.isEmpty || _tooLong ? const [] : null;
    });
    if (_query.isEmpty || _tooLong) return;
    final query = _query;
    _debounce = Timer(catalogSearchDebounce, () => _search(query, generation));
  }

  void _retry() {
    if (_results == null || _query.isEmpty || _tooLong) return;
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _error = null;
      _results = null;
    });
    _search(_query, generation);
  }

  Future<void> _search(String query, int generation) async {
    List<DrugCatalogItem> results;
    MedicationFailure? error;
    try {
      results = await _searchCatalog(query);
    } on MedicationFailure catch (failure) {
      results = const [];
      error = failure;
    }
    // Kết quả của chuỗi cũ về muộn hơn chuỗi mới thì bỏ.
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = results;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final displayedGeneration = _generation;
    return LayoutBuilder(builder: (context, constraints) {
      // Modal host reserves keyboard space; Scaffold hosts resize themselves.
      return SizedBox(
        height: constraints.maxHeight * 0.92,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
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
                    if (constraints.maxHeight > 480) ...[
                      Semantics(
                        header: true,
                        child: const Text('Chọn thuốc từ danh mục',
                            style: AppTextStyles.heading),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      autofocus: true,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tên thuốc hoặc hoạt chất',
                        prefixIcon:
                            Icon(Icons.search, color: AppColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: results == null
                    ? const Center(child: CircularProgressIndicator())
                    : _tooLong
                        ? const _SheetMessage(
                            icon: Icons.search,
                            title: 'Từ khóa quá dài',
                            message:
                                'Nhập tối đa 100 ký tự sau khi bỏ khoảng trắng đầu và cuối.',
                          )
                        : _error != null
                            ? _SheetMessage(
                                icon: Icons.cloud_off_outlined,
                                title: 'Chưa tìm được',
                                message: medicationErrorMessage(_error!),
                                onRetry: _error!.kind ==
                                        MedicationFailureKind.unauthorized
                                    ? null
                                    : _retry,
                              )
                            : _query.trim().isEmpty
                                ? const _SheetMessage(
                                    icon: Icons.search,
                                    title: 'Nhập tên thuốc hoặc hoạt chất',
                                    message:
                                        'Gõ có dấu hay không dấu đều được, ví dụ: thuoc ho.',
                                  )
                                : DrugSelectionPanel(
                                    candidates: results,
                                    source: DrugSelectionSource.search,
                                    isInUse: _isInUse,
                                    onConfirm: (item) {
                                      if (displayedGeneration == _generation &&
                                          identical(results, _results) &&
                                          mounted &&
                                          (ModalRoute.of(context)?.isCurrent ??
                                              false)) {
                                        Navigator.of(context).pop(item);
                                      }
                                    },
                                    onManualSearch: () {
                                      _focusNode.requestFocus();
                                      _textController.selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset:
                                              _textController.text.length);
                                    },
                                  ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.onRetry});

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(icon, size: 48, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(title,
              textAlign: TextAlign.center, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.caption),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ],
      ),
    );
  }
}
