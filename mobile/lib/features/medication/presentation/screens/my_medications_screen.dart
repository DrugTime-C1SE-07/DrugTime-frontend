import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/medication_failure.dart';
import '../state/medication_controller.dart';
import '../widgets/medication_card.dart';
import '../widgets/medication_error_messages.dart';
import '../widgets/medication_notices.dart';

/// S06 · Thuốc của tôi (Figma node 32:4235).
class MyMedicationsScreen extends StatefulWidget {
  const MyMedicationsScreen({super.key});

  @override
  State<MyMedicationsScreen> createState() => _MyMedicationsScreenState();
}

class _MyMedicationsScreenState extends State<MyMedicationsScreen> {
  final _searchController = TextEditingController();
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

  /// Lưu xong, luồng thêm thuốc kết thúc ở màn "Đã thêm thuốc" (S07-M4), nên ở đây không cần
  /// báo lại bằng snackbar.
  Future<void> _openAddMedication() async {
    await Navigator.of(context).pushNamed<Medication>(AppRoutes.addMedication);
  }

  void _showNotBuilt(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature đang được phát triển')));
  }

  Future<void> _openMedicationDetail(Medication medication) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.medicationDetail,
      arguments: medication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MedicationScope.of(context);
    final all = controller.medications;
    final matches = all.where(_matchesQuery).toList();
    final active = matches.where((m) => m.isActive).toList();
    final stopped = matches.where((m) => !m.isActive).toList();
    final loadError = controller.loadError;

    // Tải xong, không lỗi, chưa có thuốc: chỉ còn lời mời "Thêm thuốc mới" ở giữa, không cần
    // ô tìm kiếm hay link tra cứu.
    final emptyList = all.isEmpty && loadError == null && !controller.isLoading;
    // Nút "Thêm" ở header trùng với nút của empty-state (chưa có thuốc, hoặc tìm không khớp).
    final showsEmptyState = emptyList || (all.isNotEmpty && matches.isEmpty);

    final children = <Widget>[
      _Header(showAdd: !showsEmptyState, onAdd: _openAddMedication),
      if (!emptyList) ...[
        const SizedBox(height: AppSpacing.sm),
        _SearchField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          onClear: _clearSearch,
        ),
        const SizedBox(height: AppSpacing.sm),
        _CatalogLink(onTap: () => _showNotBuilt('Danh mục thuốc')),
      ],
    ];

    if (loadError != null) {
      children
        ..add(const SizedBox(height: AppSpacing.lg))
        ..add(_LoadErrorCard(
          message: medicationErrorMessage(loadError),
          onRetry: controller.load,
          onConsent: loadError.kind == MedicationFailureKind.consentRevoked
              ? () => openConsentScreen(context)
              : null,
        ));
    }

    if (controller.isLoading && all.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (all.isEmpty && loadError != null) {
      // Đã hiện thẻ lỗi ở trên; không báo "Chưa có thuốc nào" khi thực ra chưa tải được.
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
      children
        ..addAll(_section('Đang dùng', active, gapBefore: AppSpacing.md))
        ..addAll(_section('Đã ngừng', stopped, gapBefore: AppSpacing.lg));
    }

    return Scaffold(
      backgroundColor: AppColors.canvasCool,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              _pagePadding,
              AppSpacing.sm,
              _pagePadding,
              AppSpacing.xl,
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  /// Lề ngang 20 theo Figma S06 (rộng hơn `AppSpacing.page` của các màn khác).
  static const _pagePadding = 20.0;

  List<Widget> _section(String title, List<Medication> meds, {required double gapBefore}) {
    if (meds.isEmpty) return const [];
    return [
      SizedBox(height: gapBefore),
      Semantics(
        header: true,
        child: Text('$title · ${meds.length}', style: AppTextStyles.captionStrong),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final (i, m) in meds.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        MedicationCard(
          medication: m,
          onTap: () => _openMedicationDetail(m),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showAdd, required this.onAdd});

  /// Ẩn khi màn đang hiện nút "Thêm thuốc mới" ở giữa, để không có hai nút cùng việc.
  final bool showAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: const Text('Thuốc của tôi', style: AppTextStyles.display),
            ),
          ),
          _RoundAction(
            key: const Key('medication-interaction-history-icon-button'),
            tooltip: 'Lịch sử kiểm tra tương tác',
            icon: Icons.shield_outlined,
            background: AppColors.historyTint,
            foreground: AppColors.historyIcon,
            onTap: () => Navigator.pushNamed(context, AppRoutes.interactionHistory),
          ),
          if (showAdd) ...[
            const SizedBox(width: AppSpacing.md),
            _RoundAction(
              key: const Key('medication-add-button'),
              tooltip: 'Thêm thuốc',
              icon: Icons.add,
              background: AppColors.brandTint,
              foreground: AppColors.brand,
              onTap: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

/// Nút tròn 48×48 ở header S06.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppSizes.tapTarget,
            child: Icon(icon, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _CatalogLink extends StatelessWidget {
  const _CatalogLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Tra cứu danh mục thuốc',
                  style: AppTextStyles.captionStrong.copyWith(color: AppColors.brand),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.brand),
            ],
          ),
        ),
      ),
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

  static const _radius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body.copyWith(fontSize: 17),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        constraints: const BoxConstraints(minHeight: AppSizes.field),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        hintText: 'Tìm theo tên thuốc, hoạt chất…',
        hintStyle: const TextStyle(fontSize: 17, color: AppColors.inkFaint),
        enabledBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.brand, width: 2),
        ),
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

/// Không tải được danh sách: báo lỗi và cho thử lại. Danh sách cũ (nếu có) vẫn hiện bên dưới.
class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry, this.onConsent});

  final String message;
  final Future<void> Function() onRetry;

  /// Có khi lỗi là `consent_revoked`: nút mở màn đồng ý thay cho "Thử lại".
  final VoidCallback? onConsent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: AppTextStyles.body)),
          if (onConsent case final onConsent?)
            TextButton(
              key: const Key('consent-revoked-card-action'),
              onPressed: onConsent,
              child: const Text(consentActionLabel),
            )
          else
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
