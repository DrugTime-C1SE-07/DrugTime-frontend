import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import '../state/medication_controller.dart';
import '../widgets/medication_card.dart';
import '../widgets/medication_filter_bar.dart';
import '../widgets/medication_notices.dart';

/// S06 · Thuốc của tôi (Figma node 32:4235).
class MyMedicationsScreen extends StatefulWidget {
  const MyMedicationsScreen({super.key});

  @override
  State<MyMedicationsScreen> createState() => _MyMedicationsScreenState();
}

class _MyMedicationsScreenState extends State<MyMedicationsScreen> {
  final _searchController = TextEditingController();
  MedicationFilter _filter = MedicationFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(Medication m) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        m.name.toLowerCase().contains(q) ||
        m.activeIngredient.toLowerCase().contains(q);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _openAddMedication() async {
    final added = await Navigator.of(context).pushNamed<Medication>(AppRoutes.addMedication);
    if (!mounted || added == null) return;

    final when = added.frequency.isAsNeeded
        ? 'dùng khi cần, không đặt nhắc'
        : 'nhắc lúc ${added.times.map((t) => t.format()).join(', ')}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.safeBg),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Đã thêm ${added.name} · $when')),
            ],
          ),
        ),
      );
  }

  void _showNotBuilt(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature đang được phát triển')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = MedicationScope.of(context);
    final all = controller.medications;
    final matches = all.where(_matchesQuery).toList();
    final active = matches.where((m) => m.isActive).toList();
    final stopped = matches.where((m) => !m.isActive).toList();
    final lowStock = all.where((m) => m.isLowStock).toList();

    final children = <Widget>[
      _Header(activeCount: all.where((m) => m.isActive).length, onAdd: _openAddMedication),
      if (lowStock.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        LowStockBanner(medications: lowStock),
      ],
      const SizedBox(height: AppSpacing.lg),
      _SearchField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        onClear: _clearSearch,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _showNotBuilt('Danh mục thuốc'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs)),
          icon: const Icon(Icons.menu_book_outlined, size: 20),
          label: const Text('Tra cứu danh mục thuốc'),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      MedicationFilterBar(
        selected: _filter,
        counts: {
          MedicationFilter.all: matches.length,
          MedicationFilter.active: active.length,
          MedicationFilter.stopped: stopped.length,
        },
        onChanged: (f) => setState(() => _filter = f),
      ),
    ];

    if (controller.isLoading && all.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (all.isEmpty) {
      children.add(MedicationEmptyState(
        title: 'Chưa có thuốc nào',
        message: 'Thêm thuốc bạn đang dùng để DrugTime nhắc đúng giờ và kiểm tra tương tác.',
        onAdd: _openAddMedication,
      ));
    } else if (matches.isEmpty) {
      children.add(MedicationEmptyState(
        title: 'Không tìm thấy "${_query.trim()}"',
        message: 'Thử tìm bằng tên hoạt chất, hoặc thêm thuốc này vào danh sách.',
        onAdd: _openAddMedication,
      ));
    } else {
      if (_filter != MedicationFilter.stopped) {
        children.addAll(_section('Đang dùng', active));
      }
      if (_filter != MedicationFilter.active) {
        children.addAll(_section('Đã ngừng', stopped));
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<Medication> meds) {
    if (meds.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.xl),
      Semantics(
        header: true,
        child: Text('$title · ${meds.length}', style: AppTextStyles.captionStrong),
      ),
      const SizedBox(height: AppSpacing.md),
      for (final m in meds) ...[
        MedicationCard(
          medication: m,
          onTap: () => _showNotBuilt('Chi tiết ${m.name}'),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.activeCount, required this.onAdd});

  final int activeCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: const Text('Thuốc của tôi', style: AppTextStyles.title),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                activeCount == 0 ? 'Chưa có thuốc đang dùng' : '$activeCount thuốc đang dùng',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Nút có chữ thay cho dấu "+" trơn: người lớn tuổi hiểu ngay.
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Thêm'),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Tìm theo tên thuốc, hoạt chất…',
        prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Xoá tìm kiếm',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, color: AppColors.inkMuted),
                ),
        ),
      ),
    );
  }
}
