import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/vector_icons.dart';
import '../../domain/entities/dose_reminder.dart';
import '../state/dose_reminder_controller.dart';
import '../widgets/dose_reminder_card.dart';

/// Full-screen reminder for confirming, snoozing, or skipping a dose group.
class DoseReminderScreen extends StatefulWidget {
  const DoseReminderScreen({
    super.key,
    required this.arguments,
  });

  final DoseReminderRouteArguments arguments;

  @override
  State<DoseReminderScreen> createState() => _DoseReminderScreenState();
}

class _DoseReminderScreenState extends State<DoseReminderScreen> {
  late final DoseReminderController _controller = DoseReminderController(
    group: widget.arguments.group,
    outbox: widget.arguments.outbox,
    scheduler: widget.arguments.scheduler,
    clock: widget.arguments.clock,
  )..addListener(_onChanged);

  bool _expanded = false;
  late final Set<int> _selectedScheduleIds = <int>{};

  DoseReminderGroup get _group => widget.arguments.group;

  @override
  void initState() {
    super.initState();
    _selectedScheduleIds.addAll(_group.items.map((i) => i.medicationScheduleId));
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  DateTime get _vietnamTime =>
      _group.scheduledAt.toUtc().add(const Duration(hours: 7));

  String get _timeLabel => '${_vietnamTime.hour.toString().padLeft(2, '0')}:'
      '${_vietnamTime.minute.toString().padLeft(2, '0')}';

  String get _dateLabel {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return '${weekdays[_vietnamTime.weekday - 1]}, '
        '${_vietnamTime.day.toString().padLeft(2, '0')}/'
        '${_vietnamTime.month.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmItem(DoseReminderItem item) async {
    await _controller.confirmItem(item);
  }

  Future<void> _confirmAll() async {
    await _controller.confirmAll();
  }

  Future<void> _snooze() async {
    final succeeded = await _controller.snooze();
    if (mounted && succeeded) {
      Navigator.of(context).pop(DoseReminderResult.snoozed);
    }
  }

  void _skip() {
    final result = _controller.skip();
    if (result != null) Navigator.of(context).pop(result);
  }

  void _closeConfirmed() {
    Navigator.of(context).pop(DoseReminderResult.confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _group.items.length;

    return Scaffold(
      backgroundColor: AppColors.brandStrong,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(itemCount),
                      if (!_expanded || !_group.hasMultipleItems) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _buildMedicinePulse(),
                        const SizedBox(height: AppSpacing.xl),
                        const SizedBox(height: AppSpacing.sm),
                      ] else ...[
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_group.hasMultipleItems && !_expanded)
                        _buildStackedCards(_group.items.first, itemCount)
                      else if (_group.hasMultipleItems && _expanded) ...[
                        ..._group.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: DoseReminderCard(
                              item: item,
                              status: _controller.statusOf(item),
                              isSelectable: true,
                              isSelected: _selectedScheduleIds
                                  .contains(item.medicationScheduleId),
                              onConfirm: _controller.isBusy
                                  ? null
                                  : () => _confirmItem(item),
                              onToggleSelect: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedScheduleIds
                                        .add(item.medicationScheduleId);
                                  } else {
                                    _selectedScheduleIds
                                        .remove(item.medicationScheduleId);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ] else ...[
                        ..._group.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: DoseReminderCard(
                              item: item,
                              status: _controller.statusOf(item),
                              onConfirm: _controller.isBusy
                                  ? null
                                  : () => _confirmItem(item),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_controller.message case final message?) ...[
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      message,
                      style: AppTextStyles.captionStrong.copyWith(
                        color: const Color(0xFFFFD7D7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              _buildActions(itemCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int itemCount) {
    if (_group.hasMultipleItems && _expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_timeLabel · $_dateLabel',
            style: AppTextStyles.caption.copyWith(color: AppColors.onBrand),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$itemCount thuốc cần uống',
                  style: AppTextStyles.title.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Semantics(
                button: true,
                container: true,
                excludeSemantics: true,
                label: 'Thu gọn danh sách thuốc',
                child: InkWell(
                  onTap: () => setState(() => _expanded = false),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D746E),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Thu gọn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bỏ chọn thuốc bạn chưa uống trước khi xác nhận.',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFFB2DFDB),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1D746E),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: 18, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'DrugTime · Đến giờ uống thuốc',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FittedBox(
          child: Text(
            _timeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              height: 1,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _dateLabel,
          style: AppTextStyles.body.copyWith(color: AppColors.onBrand),
        ),
      ],
    );
  }

  Widget _buildStackedCards(DoseReminderItem firstItem, int totalCount) {
    return Semantics(
      container: true,
      label: '$totalCount thuốc cần uống. Nhấn để xem tất cả.',
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Thẻ lớp 3 (dưới cùng)
                Container(
                  margin: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                // Thẻ lớp 2 (ở giữa)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                // Thẻ chính trên cùng
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DoseReminderCard(
                    item: firstItem,
                    status: _controller.statusOf(firstItem),
                    extraCountBadge: totalCount - 1,
                    onTap: () => setState(() => _expanded = true),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: 'Xem tất cả $totalCount thuốc',
            child: InkWell(
              onTap: () => setState(() => _expanded = true),
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '$totalCount thuốc cần uống · Nhấn để xem tất cả',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onBrand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.onBrand,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinePulse() {
    if (_group.hasMultipleItems && _expanded) return const SizedBox.shrink();
    return Semantics(
      label: 'Biểu tượng nhắc uống thuốc',
      child: Container(
        width: 150,
        height: 150,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF146C66),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4C8E89),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandTint,
            ),
            child: const Icon(
              Icons.medication_outlined,
              size: 38,
              color: AppColors.brand,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(int itemCount) {
    final busy = _controller.isBusy;
    final allConfirmed = _controller.allConfirmed;

    final unconfirmedItems = _group.items
        .where((i) => _controller.statusOf(i) != DoseReminderItemStatus.confirmed)
        .toList();
    final selectedUnconfirmed = unconfirmedItems
        .where((i) => _selectedScheduleIds.contains(i.medicationScheduleId))
        .toList();

    String confirmLabel;
    if (itemCount == 1) {
      confirmLabel = 'Đã uống';
    } else if (!_expanded) {
      confirmLabel = 'Đã uống cả $itemCount thuốc';
    } else {
      if (selectedUnconfirmed.length == itemCount) {
        confirmLabel = 'Đã uống cả $itemCount thuốc';
      } else if (selectedUnconfirmed.isNotEmpty) {
        confirmLabel = 'Đã uống ${selectedUnconfirmed.length} thuốc';
      } else {
        confirmLabel = 'Chọn thuốc để xác nhận';
      }
    }

    final bool canConfirm = !busy &&
        !allConfirmed &&
        (itemCount == 1 || !_expanded || selectedUnconfirmed.isNotEmpty);

    Future<void> handleConfirm() async {
      if (itemCount == 1) {
        await _confirmItem(_group.items.first);
      } else if (!_expanded) {
        await _confirmAll();
      } else {
        if (selectedUnconfirmed.length == unconfirmedItems.length) {
          await _confirmAll();
        } else {
          for (final item in selectedUnconfirmed) {
            await _confirmItem(item);
          }
        }
      }
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: AppSizes.primaryButton,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.brand,
            ),
            onPressed: canConfirm ? handleConfirm : null,
            icon: const Icon(Icons.check),
            label: Text(confirmLabel),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: AppSizes.tapTarget,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onBrand,
              side: const BorderSide(color: Color(0xFF7AB0AC)),
            ),
            onPressed: busy || allConfirmed ? null : _snooze,
            icon: const ClockIcon(color: AppColors.onBrand, size: 20),
            label: const Text('Nhắc lại sau 10 phút'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.tapTarget,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD9E7E6),
            ),
            onPressed: busy
                ? null
                : allConfirmed
                    ? _closeConfirmed
                    : _skip,
            child: Text(
              allConfirmed ? 'Đóng' : 'Bỏ qua liều này',
            ),
          ),
        ),
      ],
    );
  }
}
