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

  DoseReminderGroup get _group => widget.arguments.group;

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
    final succeeded = await _controller.confirmItem(item);
    if (!mounted) return;
    if (succeeded && _group.items.length == 1) {
      Navigator.of(context).pop(DoseReminderResult.confirmed);
    }
  }

  Future<void> _confirmAll() async {
    final succeeded = await _controller.confirmAll();
    if (mounted && succeeded) {
      Navigator.of(context).pop(DoseReminderResult.confirmed);
    }
  }

  Future<void> _snooze() async {
    final succeeded = await _controller.snooze();
    if (mounted && succeeded) {
      Navigator.of(context).pop(DoseReminderResult.snoozed);
    }
  }

  void _skip() {
    Navigator.of(context).pop(_controller.skip());
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _group.items.length;
    final shownItems = _group.hasMultipleItems && !_expanded
        ? _group.items.take(1)
        : _group.items;

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
                      const SizedBox(height: AppSpacing.xl),
                      _buildMedicinePulse(),
                      const SizedBox(height: AppSpacing.xl),
                      const SizedBox(height: AppSpacing.sm),
                      ...shownItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: DoseReminderCard(
                            item: item,
                            status: _controller.statusOf(item),
                            onConfirm: () => _confirmItem(item),
                          ),
                        ),
                      ),
                      if (_group.hasMultipleItems)
                        _buildExpandControl(itemCount),
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
        if (_group.hasMultipleItems && _expanded)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$_timeLabel · $_dateLabel',
              style: AppTextStyles.caption.copyWith(color: AppColors.onBrand),
            ),
          )
        else ...[
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
        if (_group.hasMultipleItems && _expanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$itemCount thuốc cần uống',
              style: AppTextStyles.title.copyWith(color: AppColors.onBrand),
            ),
          ),
        ],
      ],
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

  Widget _buildExpandControl(int itemCount) {
    final remaining = itemCount - 1;
    return Semantics(
      button: true,
      expanded: _expanded,
      label:
          _expanded ? 'Thu gọn danh sách thuốc' : 'Xem tất cả $itemCount thuốc',
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: AppColors.onBrand),
        onPressed: () => setState(() => _expanded = !_expanded),
        icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
        label: Text(
          _expanded
              ? 'Thu gọn'
              : '$itemCount thuốc cần uống · +$remaining thuốc · Nhấn để xem tất cả',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActions(int itemCount) {
    final busy = _controller.isConfirmingGroup || _controller.isSnoozing;
    final confirmLabel = itemCount == 1
        ? (_controller.allConfirmed ? 'Đã uống' : 'Đã uống')
        : 'Đã uống cả $itemCount thuốc';

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
            onPressed: busy || _controller.allConfirmed
                ? null
                : itemCount == 1
                    ? () => _confirmItem(_group.items.first)
                    : _confirmAll,
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
            onPressed: busy ? null : _snooze,
            icon: const ClockIcon(color: AppColors.onBrand, size: 20),
            label: const Text('Nhắc lại sau 10 phút'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.tapTarget,
          child: TextButton(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFD9E7E6)),
            onPressed: busy ? null : _skip,
            child: const Text('Bỏ qua liều này'),
          ),
        ),
      ],
    );
  }
}
