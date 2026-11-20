import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../family_link/presentation/garden/care_garden.dart';
import '../../../family_link/presentation/garden/garden_mood.dart';
import 'monitor_palette.dart';

/// Đầu màn "Hôm nay của …" (R2): quay lại, mở lịch sử, nhãn chỉ xem, tên, chip số liều và
/// chuỗi ngày, rồi cảnh khu vườn của riêng người này.
class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.patientId,
    required this.name,
    required this.confirmed,
    required this.total,
    required this.streak,
    required this.mood,
    required this.plant,
    required this.onBack,
    required this.onHistory,
  });

  final String patientId, name;
  final int confirmed, total, streak;
  final GardenMood mood;
  final PlantShape plant;
  final VoidCallback onBack, onHistory;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = MonitorColors.avatar(patientId);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9E2FA), MonitorColors.canvas],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _RoundButton(
              icon: Icons.chevron_left, tooltip: 'Quay lại', onTap: onBack),
          const Spacer(),
          _RoundButton(
              icon: Icons.calendar_month_outlined,
              tooltip: 'Lịch sử uống thuốc',
              onTap: onHistory),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.people_outline,
              size: 20, color: MonitorColors.purple),
          const SizedBox(width: 6),
          Text('Đang xem · chỉ xem',
              style: AppTextStyles.captionStrong
                  .copyWith(color: MonitorColors.purple)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Hero(
            tag: 'patient-avatar-$patientId',
            child: CircleAvatar(
              radius: 20,
              backgroundColor: bg,
              child: Text(nameInitials(name),
                  style: AppTextStyles.bodyStrong.copyWith(color: fg)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: AppTextStyles.display,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Chip(icon: Icons.check, label: '$confirmed/$total liều'),
          _Chip(
              icon: Icons.trending_up,
              label:
                  streak == 0 ? 'Chưa có chuỗi ngày' : '$streak ngày liên tục',
              color: const Color(0xFFB4561E)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CareGarden(
            key: const Key('today-garden'),
            height: 170,
            mood: mood,
            plants: [
              GardenPlant(
                  id: patientId, label: 'Chậu cây của $name', shape: plant),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.brand),
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color ?? AppColors.brand),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodyStrong),
        ]),
      );
}
