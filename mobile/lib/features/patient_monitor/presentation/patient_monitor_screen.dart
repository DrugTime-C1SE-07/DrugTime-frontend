import 'dart:async';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../adherence/domain/entities/adherence_history.dart';
import '../../family_link/presentation/state/family_link_scope.dart';
import '../../meal_suggestion/data/meal_choice_store.dart';
import '../../meal_suggestion/data/repositories/family_meal_suggestion_repository.dart';
import '../../meal_suggestion/domain/entities/meal_suggestion.dart';
import '../../meal_suggestion/domain/repositories/allergy_profile_repository.dart';
import '../../meal_suggestion/domain/repositories/meal_suggestion_repository.dart';
import '../../meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import '../../meal_suggestion/presentation/state/dietary_session.dart';
import '../../meal_suggestion/presentation/state/meal_choice_controller.dart';
import '../../meal_suggestion/presentation/state/meal_plan_controller.dart';
import '../../meal_suggestion/presentation/state/meal_plan_scope.dart';
import '../../patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import '../domain/monitor_digest.dart';
import '../domain/monitor_models.dart';
import 'patient_monitor_controller.dart';
import 'widgets/cabinet_view.dart';
import 'widgets/care_status_card.dart';
import 'widgets/dose_detail_view.dart';
import 'widgets/dose_row.dart';
import 'widgets/history_view.dart';
import 'widgets/interaction_detail_view.dart';
import 'widgets/lost_access_view.dart';
import 'widgets/monitor_palette.dart';
import 'widgets/today_header.dart';

/// Màn theo dõi một người (phía người thân, chỉ xem — QD-27).
///
/// Các màn con: hôm nay (R2a–R2d), chi tiết liều (R3), tủ thuốc (R5), cảnh báo tương tác
/// (R5a), lịch sử (R6), không còn xem được (R8). Mọi dữ liệu đi qua
/// [PatientMonitorController]; 403 ở bất kỳ request nào chuyển sang R8.
class PatientMonitorScreen extends StatefulWidget {
  const PatientMonitorScreen({
    super.key,
    required this.patientId,
    this.mealRepositoryBuilder,
    this.mealAllergyRepositoryBuilder,
  });
  final String patientId;

  /// Cho phép test/tầng ngoài thay thế kho `MOCK(6.11)`.
  final MealSuggestionRepository Function(PatientMonitorController controller)?
      mealRepositoryBuilder;
  final AllergyProfileRepository Function(PatientMonitorController controller)?
      mealAllergyRepositoryBuilder;
  @override
  State<PatientMonitorScreen> createState() => _PatientMonitorScreenState();
}

class _PatientMealHost {
  _PatientMealHost({
    required this.patientId,
    required this.sessionRevision,
    required this.plan,
    required this.choices,
    required this.dietarySession,
  });

  final String patientId;
  final int sessionRevision;
  final MealPlanController plan;
  final MealChoiceController choices;
  final DietarySession dietarySession;

  void dispose() {
    plan.reset();
    dietarySession.clear();
    unawaited(choices.clear());
    plan.dispose();
    choices.dispose();
  }
}

class _PatientMonitorScreenState extends State<PatientMonitorScreen> {
  String _view = 'today';
  OccurrenceKey? _doseKey;
  int _monthOffset = 0;
  bool _monthly = false;
  Timer? _ticker;
  _PatientMealHost? _mealHost;
  PatientMonitorController? _observedController;

  /// Tên cuối cùng đã biết, để màn R8 vẫn gọi đúng tên sau khi danh sách bị thu hồi.
  String _lastName = '';
  PatientMonitorController? get _controller =>
      FamilyLinkScope.maybeOf(context)?.monitor;

  @override
  void initState() {
    super.initState();
    // đếm ngược thời gian chờ nhắc lại
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_view == 'dose' || _view == 'today')) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _controller;
    if (!identical(_observedController, next)) {
      _observedController?.removeListener(_syncMealHostAccess);
      _observedController = next;
      _observedController?.addListener(_syncMealHostAccess);
      _syncMealHostAccess();
    }
  }

  @override
  void didUpdateWidget(covariant PatientMonitorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _clearMealHost();
    }
  }

  @override
  void dispose() {
    _observedController?.removeListener(_syncMealHostAccess);
    _clearMealHost();
    _ticker?.cancel();
    super.dispose();
  }

  void _syncMealHostAccess() {
    final host = _mealHost;
    if (host == null) return;
    final c = _observedController;
    final valid = c != null &&
        c.ready &&
        !c.denied &&
        c.patientId == widget.patientId &&
        host.patientId == widget.patientId &&
        host.sessionRevision == c.sessionRevision;
    if (!valid) {
      _clearMealHost();
    }
  }

  void _clearMealHost() {
    _mealHost?.dispose();
    _mealHost = null;
  }

  _PatientMealHost _ensureMealHost(PatientMonitorController controller) {
    final existing = _mealHost;
    if (existing != null &&
        existing.patientId == widget.patientId &&
        existing.sessionRevision == controller.sessionRevision) {
      return existing;
    }
    _clearMealHost();
    final id = widget.patientId;
    MealFailureKind? checkAccess(String targetId) =>
        (!controller.ready || controller.denied || controller.patientId != targetId)
            ? MealFailureKind.forbidden
            : null;
    final session = DietarySession.isolated();
    final repo = widget.mealRepositoryBuilder?.call(controller) ??
        FamilyMealSuggestionRepository(accessCheck: checkAccess, now: controller.clock);
    final allergyRepo = widget.mealAllergyRepositoryBuilder?.call(controller) ??
        FamilyAllergyProfileRepository(patientId: id, accessCheck: checkAccess);
    final plan = MealPlanController(
      repository: repo,
      allergyRepository: allergyRepo,
      session: session,
      now: controller.clock,
    )..bind(id);
    final choices = MealChoiceController(
      store: MemoryMealChoiceStore(),
      readOnly: true,
      now: controller.clock,
    )..bind(id);
    final created = _PatientMealHost(
      patientId: id,
      sessionRevision: controller.sessionRevision,
      plan: plan,
      choices: choices,
      dietarySession: session,
    );
    _mealHost = created;
    return created;
  }

  void _openMealSuggestion(PatientMonitorController controller) {
    if (!controller.ready ||
        controller.denied ||
        controller.patientId != widget.patientId) {
      return;
    }
    final host = _ensureMealHost(controller);
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MealPlanScope(
          plan: host.plan,
          choices: host.choices,
          child: MealSuggestionScreen(
            patientId: widget.patientId,
            patientName: controller.patientName,
            caregiverMode: true,
            accessRevokedListenable: controller,
            isAccessRevoked: () =>
                !controller.ready ||
                controller.denied ||
                controller.patientId != widget.patientId,
            onAccessDenied: (failure) {
              if (identical(_mealHost, host)) {
                _clearMealHost();
              } else {
                host.dispose();
              }
              if (failure.kind == MealFailureKind.forbidden) {
                controller.revoke(widget.patientId);
              }
            },
            onDeclareAllergy: (_) async => false,
          ),
        ),
      ),
    ));
  }

  void _backToHub() {
    _clearMealHost();
    _controller?.leave();
    Navigator.of(context).pop();
  }

  void _open(String view) {
    setState(() => _view = view);
    if (view == 'history') _loadRange();
    if (view == 'interactions' || view == 'medications') {
      final c = _controller;
      if (c != null && c.interactions == null) {
        unawaited(c.loadInteractions());
      }
    }
  }

  void _openDose(PatientMonitorController controller, AdherenceDose dose) {
    _doseKey = (dose.scheduleId, dose.scheduledAt.toUtc());
    _open('dose');
    if (dose.scheduledAt.isBefore(controller.clock())) {
      unawaited(controller.reminders.loadStatus(_doseKey!));
    }
  }

  Future<void> _nudge(
      PatientMonitorController controller, OccurrenceKey key) async {
    final reminders = controller.reminders;
    final before = reminders.receipt(key)?.id;
    await reminders.send(key);
    if (!mounted) return;
    final after = reminders.receipt(key);
    if (after != null && after.id != before) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          key: const Key('nudge-sent'),
          content: Text('Đã gửi lời nhắc tới ${controller.patientName}'),
        ));
    }
  }

  void _loadRange() {
    final controller = _controller;
    if (controller == null) return;
    final today = monitorDay(controller.clock());
    final month = DateTime.utc(today.year, today.month + _monthOffset);
    final start =
        _monthly ? month : today.subtract(Duration(days: today.weekday - 1));
    final end = _monthly && _monthOffset < 0
        ? DateTime.utc(month.year, month.month + 1, 0)
        : today;
    unawaited(controller.loadHistory(start, end));
  }

  String get _title => switch (_view) {
        'dose' => 'Chi tiết liều',
        'medications' => 'Tủ thuốc',
        'interactions' => 'Cảnh báo tương tác',
        'history' => 'Lịch sử uống thuốc',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Người bệnh')),
          body: const Center(child: Text('Chưa kết nối dữ liệu theo dõi.')));
    }
    return ListenableBuilder(
        listenable: Listenable.merge([controller, controller.reminders]),
        builder: (context, _) {
          final valid = controller.ready &&
              !controller.denied &&
              controller.patientId == widget.patientId;
          if (valid) _lastName = controller.patientName;
          final today = _view == 'today';
          return PopScope(
            canPop: today || !valid,
            onPopInvokedWithResult: (popped, _) {
              if (!popped) _open('today');
            },
            child: Scaffold(
              backgroundColor: MonitorColors.canvas,
              // màn hôm nay có đầu riêng (TodayHeader); lúc đang tải chưa có đầu thì dùng AppBar
              appBar: valid && (!today || controller.snapshot == null)
                  ? AppBar(
                      backgroundColor: MonitorColors.canvas,
                      leading: IconButton(
                          tooltip: 'Quay lại',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: today ? _backToHub : () => _open('today')),
                      title: Text(today ? controller.patientName : _title),
                    )
                  : null,
              body: SafeArea(
                child: !valid
                    ? LostAccessView(
                        key: const Key('monitor-lost'),
                        name: _lastName,
                        signedIn: controller.ready,
                        onBack: _backToHub)
                    : RefreshIndicator(
                        onRefresh: () async {
                          await controller.refresh();
                          if (_view == 'history') _loadRange();
                          if (_view == 'interactions' ||
                              _view == 'medications') {
                            await controller.loadInteractions();
                          }
                          if (_view == 'dose' && _doseKey != null) {
                            await controller.reminders.loadStatus(_doseKey!);
                          }
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            if (today && controller.snapshot != null)
                              _header(controller),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.page),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _body(controller),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        });
  }

  List<Widget> _body(PatientMonitorController controller) {
    if (controller.loading) {
      return [
        const SizedBox(height: 24),
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Đang tải dữ liệu được chia sẻ…')
      ];
    }
    if (controller.error != null) {
      return [
        Text(controller.error!),
        TextButton(onPressed: controller.refresh, child: const Text('Thử lại'))
      ];
    }
    if (controller.snapshot == null) {
      return [const Text('Chưa có dữ liệu được chia sẻ.')];
    }
    final chip = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: MonitorColors.purpleTint,
            borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.people_outline,
              size: 18, color: MonitorColors.purple),
          const SizedBox(width: 6),
          Text('${controller.patientName} · chỉ xem',
              style: AppTextStyles.captionStrong
                  .copyWith(color: MonitorColors.purple)),
        ]),
      ),
    );
    return switch (_view) {
      'dose' => [chip, ..._doseDetail(controller)],
      'medications' => [chip, _cabinet(controller)],
      'interactions' => [chip, ..._interactions(controller)],
      'history' => [chip, _history(controller)],
      _ => _today(controller),
    };
  }

  Widget _header(PatientMonitorController controller) {
    final data = controller.snapshot!;
    final doses = data.dosesForDay(controller.clock());
    final summary = hubSummary(doses, data.report.history.asOf);
    final mood = controller.careMoodToday ?? CareMood.ok;
    return TodayHeader(
      patientId: widget.patientId,
      name: controller.patientName,
      confirmed: summary.confirmed,
      total: summary.total,
      streak: streakDays(data.report.history, controller.clock()),
      mood: gardenMoodFor(mood),
      plant: plantShapeFor(mood),
      onBack: _backToHub,
      onHistory: () => _open('history'),
    );
  }

  List<Widget> _today(PatientMonitorController controller) {
    final data = controller.snapshot!;
    final asOf = data.report.history.asOf;
    final now = controller.clock();
    final doses = data.dosesForDay(now);
    final mood = controller.careMoodToday ?? CareMood.ok;
    final attention = controller.attentionDoses;
    // card trạng thái: liều cần chú ý đầu tiên, hoặc liều uống bù gần nhất
    AdherenceDose? focus;
    if (attention.isNotEmpty) {
      focus = attention.firstWhere(
          (d) =>
              controller.reminders
                  .receipt((d.scheduleId, d.scheduledAt.toUtc())) !=
              null,
          orElse: () => attention.first);
    } else if (mood == CareMood.recovered) {
      focus = doses.lastWhere((d) => segmentOf(d, asOf) == DoseSegment.late);
    }
    final key =
        focus == null ? null : (focus.scheduleId, focus.scheduledAt.toUtc());
    final reminders = controller.reminders;
    return [
      Row(children: [
        Expanded(
          child: _QuickAction(
            key: const Key('quick-nudge'),
            icon: Icons.notifications_none_rounded,
            label: 'Nhắc',
            color: const Color(0xFFB4561E),
            onTap: attention.isEmpty || key == null
                ? null
                : reminders.busy(key) || reminders.wait(key) > Duration.zero
                    ? null
                    : () => _nudge(controller, key),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            key: const Key('quick-cabinet'),
            icon: Icons.medication_outlined,
            label: 'Tủ thuốc',
            color: const Color(0xFF1F5E9E),
            onTap: () => _open('medications'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      CareStatusCard(
        mood: mood,
        name: controller.patientName,
        now: now,
        dose: focus,
        receipt: key == null ? null : reminders.receipt(key),
        wait: key == null ? Duration.zero : reminders.wait(key),
        busy: key != null && reminders.busy(key),
        message: key == null ? null : reminders.message(key),
        onNudge: key == null ? null : () => _nudge(controller, key),
      ),
      const SizedBox(height: 16),
      Row(children: [
        const Expanded(child: Text('Liều hôm nay', style: AppTextStyles.title)),
        TextButton(
            onPressed: () => _open('history'),
            child: const Text('Xem 7 ngày ›')),
      ]),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          if (doses.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Hôm nay không có lịch uống.')),
          for (final dose in doses)
            DoseRow(
              key: ValueKey('dose-row-${dose.scheduleId}'),
              dose: dose,
              asOf: asOf,
              onTap: () => _openDose(controller, dose),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      ListTile(
        key: const Key('open-interactions'),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: const Icon(Icons.rule_outlined),
        title: const Text('Tương tác thuốc và thực phẩm'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open('interactions'),
      ),
      const SizedBox(height: 10),
      ListTile(
        key: const Key('open-meal-suggestion'),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: const Icon(Icons.restaurant_menu_rounded),
        title: const Text('Gợi ý bữa ăn'),
        subtitle: Text('Thực đơn theo thuốc của ${controller.patientName}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openMealSuggestion(controller),
      ),
      const SizedBox(height: 8),
      Text(
          data.report.checkpoint == null
              ? 'Cập nhật lúc ${monitorTime(asOf)} · chưa có mốc đồng bộ từ điện thoại người bệnh'
              : 'Cập nhật lúc ${monitorTime(asOf)} · điện thoại người bệnh đồng bộ ${monitorTime(data.report.checkpoint!)}',
          style: AppTextStyles.caption),
    ];
  }

  List<Widget> _doseDetail(PatientMonitorController controller) {
    final key = _doseKey;
    if (key == null) return [const Text('Không tìm thấy lần uống.')];
    final matches = controller.snapshot!.dosesForDay(controller.clock()).where(
        (d) => d.scheduleId == key.$1 && d.scheduledAt.toUtc() == key.$2);
    if (matches.isEmpty) {
      return [const Text('Lần uống đã thay đổi. Hãy tải lại hôm nay.')];
    }
    final dose = matches.first, reminder = controller.reminders;
    final now = controller.clock();
    final canRemind = dose.takenAt == null &&
        dose.scheduledAt.isBefore(now) &&
        dose.scheduledAt.isAfter(now.subtract(const Duration(days: 30)));
    return [
      DoseDetailView(
        dose: dose,
        history: controller.snapshot!.report.history,
        name: controller.patientName,
        now: now,
        receipt: reminder.receipt(key),
        canRemind: canRemind,
        wait: reminder.wait(key),
        busy: reminder.busy(key),
        message: reminder.message(key),
        onNudge: () => _nudge(controller, key),
      ),
    ];
  }

  Widget _cabinet(PatientMonitorController controller) => CabinetView(
        medications: controller.snapshot!.medications,
        interactions: controller.interactions,
        foodWarnings: [
          for (final m
              in (controller.food?['medications'] as List? ?? const []))
            ...((m as Map)['warnings'] as List? ?? const [])
        ].length,
        onOpenInteractions: () => _open('interactions'),
      );

  List<Widget> _interactions(PatientMonitorController controller) {
    final drugs = controller.interactions, food = controller.food;
    if (controller.interactionError != null) {
      return [
        Text(controller.interactionError!),
        TextButton(
            onPressed: controller.loadInteractions,
            child: const Text('Thử lại'))
      ];
    }
    if (drugs == null || food == null) return [const LinearProgressIndicator()];
    return [InteractionDetailView(drugs: drugs, food: food)];
  }

  Widget _history(PatientMonitorController controller) => HistoryView(
        monthly: _monthly,
        monthOffset: _monthOffset,
        now: controller.clock(),
        history: controller.range?.history,
        error: controller.rangeError,
        onMode: (monthly) {
          setState(() {
            _monthly = monthly;
            _monthOffset = 0;
          });
          _loadRange();
        },
        onMonth: (offset) {
          setState(() => _monthOffset = offset);
          _loadRange();
        },
        onRetry: _loadRange,
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: enabled ? .12 : .05),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: enabled ? color : AppColors.inkDisabled),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                      color: enabled ? AppColors.ink : AppColors.inkDisabled)),
            ),
          ]),
        ),
      ),
    );
  }
}
