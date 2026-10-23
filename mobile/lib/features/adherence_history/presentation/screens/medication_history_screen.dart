import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/adherence_history.dart';
import '../state/adherence_history_controller.dart';
import '../widgets/adherence_calendar.dart';
import '../widgets/history_summary.dart';
import '../widgets/medication_history_list.dart';
import '../widgets/history_motion.dart';
import '../widgets/history_feedback.dart';
import '../widgets/history_info_sheet.dart';
import '../../../../core/preview/app_preview_scope.dart';

class MedicationHistoryScreen extends StatelessWidget {
  const MedicationHistoryScreen({super.key, this.onRetry});
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AdherenceHistoryScope.of(context);
    return HistoryMotionScope(
        child: Scaffold(
            body: SafeArea(
                child: RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(children: [
            BackButton(onPressed: () => Navigator.of(context).pop()),
            const Expanded(
                child: Text('Theo thuốc', style: AppTextStyles.title)),
            const AppPreviewBadge(),
            const HistoryInfoButton(),
          ]),
          const SizedBox(height: AppSpacing.lg),
          HistoryMonthHeader(controller: c),
          const SizedBox(height: AppSpacing.lg),
          if (c.loading || c.error != null)
            HistoryLoadState(controller: c, onRetry: onRetry)
          else if (c.history?.mode == HistoryMode.medication) ...[
            HistorySummary(summary: c.history!.summary),
            const SizedBox(height: AppSpacing.lg),
            MedicationHistoryList(controller: c),
            if (c.history!.summary.total == 0)
              const HistoryEmpty(medication: true),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    ))));
  }
}
