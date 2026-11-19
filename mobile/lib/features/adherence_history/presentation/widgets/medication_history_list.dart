import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/pill_icon.dart';
import '../state/adherence_history_controller.dart';
import '../utils/adherence_history_format.dart';
import 'dose_history_tile.dart';
import 'history_motion.dart';
import 'history_inline_row.dart';

class MedicationHistoryList extends StatelessWidget {
  const MedicationHistoryList({super.key, required this.controller});
  final AdherenceHistoryController controller;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final group in controller.history!.medications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    expanded: controller.expanded(group.medicationId),
                    child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            side: const BorderSide(color: AppColors.border)),
                        child: InkWell(
                          key: ValueKey(
                              'history-medication-${group.medicationId}'),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          onTap: () =>
                              controller.toggleMedication(group.medicationId),
                          child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ExcludeSemantics(
                                        child: PillTile(size: 40)),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(group.name,
                                              style: AppTextStyles.bodyStrong),
                                          HistoryInlineRow(children: [
                                            Text(
                                                '${HistoryFormat.rate(group.summary.rate)} · ${group.summary.total} liều${group.summary.pending > 0 ? ' · ${group.summary.pending} chờ' : ''}',
                                                style: AppTextStyles.caption)
                                          ]),
                                        ])),
                                    if (HistoryMotion.enabled(context))
                                      AnimatedRotation(
                                          turns: controller
                                                  .expanded(group.medicationId)
                                              ? .5
                                              : 0,
                                          duration: HistoryMotion.selection,
                                          child: Icon(Icons.expand_more,
                                              key: ValueKey(
                                                  'history-expand-${group.medicationId}')))
                                    else
                                      Icon(
                                          controller
                                                  .expanded(group.medicationId)
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          key: ValueKey(
                                              'history-expand-${group.medicationId}')),
                                  ])),
                        )),
                  ),
                  HistoryExpandableSize(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        if (controller.expanded(group.medicationId)) ...[
                          const SizedBox(height: AppSpacing.md),
                          for (final (index, dose) in group.doses.indexed)
                            HistoryEntrance(
                                key: ValueKey((
                                  controller,
                                  controller.contentRevision,
                                  group.medicationId,
                                  dose.scheduleId,
                                  dose.scheduledAt
                                )),
                                index: index,
                                child: DoseHistoryTile(
                                    dose: dose, showDate: true)),
                        ]
                      ])),
                ]),
          ),
      ]);
}
