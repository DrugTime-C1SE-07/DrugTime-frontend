import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import 'history_motion.dart';

class HistoryEmpty extends StatelessWidget {
  const HistoryEmpty({super.key, this.medication = false});
  final bool medication;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(children: [
        ExcludeSemantics(
            child: SizedBox(
                width: 80,
                height: 72,
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.event_note_outlined,
                      size: 64, color: AppColors.brand),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: AppColors.surface, shape: BoxShape.circle),
                          child: const PillIcon(size: 24))),
                ]))),
        const SizedBox(height: AppSpacing.md),
        const Text('Chưa có lịch sử',
            style: AppTextStyles.body, textAlign: TextAlign.center),
      ]));
}

class HistoryLoading extends StatelessWidget {
  const HistoryLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      liveRegion: true,
      label: 'Đang tải lịch sử',
      child: ExcludeSemantics(
          child: HistoryShimmer(
              base: AppColors.surfaceMuted,
              highlight: AppColors.brandTint,
              child: Column(children: [
                for (var i = 0; i < 2; i++)
                  Container(
                      height: 108,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.card)),
                      child: Row(children: [
                        const PillTile(muted: true),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                      color: AppColors.border,
                                      borderRadius: BorderRadius.circular(8))),
                              const SizedBox(height: AppSpacing.md),
                              FractionallySizedBox(
                                  widthFactor: .6,
                                  child: Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                          color: AppColors.border,
                                          borderRadius:
                                              BorderRadius.circular(6)))),
                            ])),
                      ])),
              ]))));
}
