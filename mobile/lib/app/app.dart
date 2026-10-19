import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/contracts/dose_outbox.dart';
import '../core/notification/notification_id.dart';
import '../core/notification/notification_service.dart';
import '../core/notification/reminder_scheduler.dart';
import '../core/platform/keyguard_service.dart';
import '../core/storage/local_db/local_medication_store.dart';
import '../core/storage/local_db/local_models.dart';
import '../core/sync/sync_engine.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import '../features/consent/data/repositories/in_memory_consent_repository.dart';
import '../features/consent/domain/repositories/consent_repository.dart';
import '../features/consent/presentation/state/consent_controller.dart';
import '../features/family/domain/entities/family_link_code.dart';
import '../features/family/domain/entities/family_link_code_failure.dart';
import '../features/family/domain/repositories/family_link_code_repository.dart';
import '../features/family/presentation/state/family_link_code_controller.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/repositories/medication_repository.dart';
import '../features/medication/presentation/state/medication_controller.dart';
import '../features/reminder/domain/entities/dose_reminder.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/state/profile_controller.dart';
import 'router.dart';
import '../core/utils/app_assets.dart';
import 'theme/app_theme.dart';

class DrugTimeApp extends StatefulWidget {
  const DrugTimeApp({
    super.key,
    required this.authController,
    this.medicationRepository,
    this.consentRepository,
    this.familyLinkCodeRepository,
    this.profileRepository,
    this.doseOutboxSyncEngine,
    this.localMedicationStore,
    this.doseOutbox,
    this.reminderScheduler,
    this.keyguardPlatform,
    this.clock,
    this.initialRoute,
    this.navigatorKey,
    this.scaffoldMessengerKey,
    this.notificationService,
  });

  /// Trạng thái đăng nhập; app chạy thật dựng với RemoteAuthRepository (xem main.dart).
  final AuthController authController;

  /// Cho phép test/bản build khác thay nguồn dữ liệu thuốc.
  final MedicationRepository? medicationRepository;

  /// Không truyền thì dùng consent trong bộ nhớ đã đồng ý `health_data` (vào thẳng Trang chủ).
  final ConsentRepository? consentRepository;

  /// Cho phép test thay nguồn lấy mã liên kết; bản thật dùng Backend API.
  final FamilyLinkCodeRepository? familyLinkCodeRepository;
  final ProfileRepository? profileRepository;
  final DoseOutboxSyncEngine? doseOutboxSyncEngine;

  /// Kho lưu trữ lịch và liều thuốc cục bộ (dùng tra cứu khi bấm thông báo).
  final LocalMedicationStore? localMedicationStore;

  /// Hàng đợi ghi nhận liều offline.
  final DoseOutbox? doseOutbox;

  /// Bộ điều phối hoãn/lên lịch nhắc.
  final ReminderScheduler? reminderScheduler;

  /// Bộ kiểm tra trạng thái màn hình khóa.
  final KeyguardPlatform? keyguardPlatform;

  /// Đồng hồ tiêm vào phục vụ test thời gian.
  final DateTime Function()? clock;

  /// Khóa hiển thị SnackBar toàn cục.
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  /// Ép route đầu (test, dev catalog). Không truyền thì chọn theo phiên đăng nhập.
  final String? initialRoute;

  /// Khóa điều hướng cấp cao nhất; cho phép test hoặc bên ngoài chủ động điều hướng.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Dịch vụ thông báo để tiếp nhận sự kiện click thông báo và điều hướng cold start.
  final NotificationService? notificationService;

  @override
  State<DrugTimeApp> createState() => _DrugTimeAppState();
}

class _DrugTimeAppState extends State<DrugTimeApp> {
  late final GlobalKey<NavigatorState> _navigatorKey =
      widget.navigatorKey ?? GlobalKey<NavigatorState>();
  late final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      widget.scaffoldMessengerKey ?? GlobalKey<ScaffoldMessengerState>();

  late final MedicationController _medications = MedicationController(
    widget.medicationRepository ?? InMemoryMedicationRepository(),
  );

  late final ConsentController _consents = ConsentController(
    widget.consentRepository ?? InMemoryConsentRepository(),
  );

  late final FamilyLinkCodeController _familyLinkCode =
      FamilyLinkCodeController(
    widget.familyLinkCodeRepository ?? _UnavailableFamilyLinkCodeRepository(),
  );

  AuthController get _auth => widget.authController;
  late final ProfileController _profiles =
      ProfileController(widget.profileRepository);
  String? _profileUser;
  bool _hadHealthConsent = false;

  void _onConsentChanged() {
    final granted = _consents.hasHealthData;
    if (_hadHealthConsent && !granted) _profiles.revoke();
    _hadHealthConsent = granted;
  }

  bool _sessionLoaded = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) unawaited(syncEngine.start());
    _auth.addListener(_onAuthChanged);
    _setupNotificationHandling();
    _consents.addListener(_onConsentChanged);
    unawaited(_loadSession());
  }

  void _setupNotificationHandling() {
    widget.notificationService?.setNotificationActionHandler((payload) async {
      await _handleNotificationPayload(payload);
    });
  }

  Future<void> _handleNotificationPayload(NotificationPayload payload) async {
    final store = widget.localMedicationStore;
    if (store == null) return;

    final targetSchedule =
        await store.getScheduleById(payload.medicationScheduleId);
    if (targetSchedule == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Lịch uống thuốc không còn tồn tại.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Tra tất cả các thuốc cùng mốc giờ (cùng scheduled_at)
    final allSchedules = await store.getActiveSchedules(
      patientId: targetSchedule.patientUserId,
    );

    // Múi giờ Việt Nam UTC+7
    final vnTime = payload.scheduledAt.toUtc().add(const Duration(hours: 7));
    final targetHour = vnTime.hour;
    final targetMinute = vnTime.minute;
    final targetWeekday = vnTime.weekday;

    final matchingSchedules = allSchedules.where((s) {
      if (s.id == targetSchedule.id) return true;
      if (!s.reminderEnabled) return false;
      if (!s.daysOfWeek.contains(targetWeekday)) return false;
      if (payload.scheduledAt.isBefore(s.effectiveFrom)) return false;
      if (s.endedAt != null && !payload.scheduledAt.isBefore(s.endedAt!)) {
        return false;
      }
      final parts = s.intakeTime.split(':');
      if (parts.length < 2) return false;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      return hour == targetHour && minute == targetMinute;
    }).toList();

    // Loại các liều đã có bản ghi trong local_dose_logs
    final unrecordedSchedules = <LocalMedicationSchedule>[];
    for (final s in matchingSchedules) {
      final recorded = await store.hasDoseLog(
        medicationScheduleId: s.id,
        scheduledAt: payload.scheduledAt,
      );
      if (!recorded) {
        unrecordedSchedules.add(s);
      }
    }

    if (unrecordedSchedules.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Các liều thuốc này đã được ghi nhận.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final items = unrecordedSchedules.map((s) {
      final dosageText = s.strengthText != null
          ? '${s.quantityPerDose} viên · ${s.strengthText}'
          : '${s.quantityPerDose} viên';
      final instruction = s.dosageForm ?? 'Đúng giờ';
      return DoseReminderItem(
        medicationScheduleId: s.id,
        scheduledAt: payload.scheduledAt,
        medicationName: s.medicationName,
        dosageText: dosageText,
        instruction: instruction,
      );
    }).toList();

    final group = DoseReminderGroup(items);
    final outbox = widget.doseOutbox ?? _FallbackDoseOutbox();
    final scheduler =
        widget.reminderScheduler ?? _FallbackReminderScheduler();

    final args = DoseReminderRouteArguments(
      group: group,
      outbox: outbox,
      scheduler: scheduler,
      clock: widget.clock,
      keyguardPlatform: widget.keyguardPlatform,
    );

    _navigatorKey.currentState?.pushNamed(
      AppRoutes.doseReminder,
      arguments: args,
    );
  }

  Future<void> _loadSession() async {
    await _auth.initSession();
    if (!mounted) return;
    setState(() {
      _sessionLoaded = true;
      _wasAuthenticated = _auth.isAuthenticated;
      _profileUser =
          _auth.isAuthenticated ? _auth.currentSession?.userId : null;
    });
    if (_auth.isAuthenticated) unawaited(_medications.load());
  }

  void _onAuthChanged() {
    if (!_sessionLoaded) return;
    final authenticated = _auth.isAuthenticated;
    final user = authenticated ? _auth.currentSession?.userId : null;
    final switchedUser = user != _profileUser;
    if (switchedUser) {
      _profiles.clear();
      _profileUser = user;
    }
    if (_wasAuthenticated && !authenticated) {
      _medications.clear();
      _consents.clear();
      _familyLinkCode.clear();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else if (!_wasAuthenticated && authenticated) {
      unawaited(_medications.load());
    } else if (switchedUser && authenticated) {
      _medications.clear();
      _consents.clear();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      unawaited(_medications.load());
    }
    _wasAuthenticated = authenticated;
  }

  String get _startRoute {
    if (widget.initialRoute case final route?) return route;
    if (!_auth.isAuthenticated) return AppRoutes.login;
    return _auth.needsProfile ? AppRoutes.completeProfile : AppRoutes.home;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _consents.removeListener(_onConsentChanged);
    _profiles.dispose();
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) unawaited(syncEngine.dispose());
    _medications.dispose();
    _consents.dispose();
    _familyLinkCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MedicationScope(
        controller: _medications,
        child: ConsentScope(
          controller: _consents,
          child: FamilyLinkCodeScope(
            controller: _familyLinkCode,
          child: ProfileScope(
            controller: _profiles,
            child: _sessionLoaded ? _buildApp() : const _SessionLoadingApp(),
          ),
        ),
      ),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'DrugTime',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: _startRoute,
      onGenerateRoute: onGenerateRoute,
      // Chỉ dựng đúng một route đầu; mặc định Flutter tách '/login' thành ['/', '/login'],
      // khiến nút Back ở màn Đăng nhập quay về Trang chủ khi chưa đăng nhập.
      onGenerateInitialRoutes: (name) =>
          [onGenerateRoute(RouteSettings(name: name))!],
    );
  }
}

class _SessionLoadingApp extends StatelessWidget {
  const _SessionLoadingApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _SessionLoadingScreen(),
      );
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.mascotHello,
              width: (width * 0.7).clamp(0.0, 280.0),
              cacheWidth: 840,
              fit: BoxFit.contain,
              semanticLabel: 'DrugTime',
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

class _UnavailableFamilyLinkCodeRepository implements FamilyLinkCodeRepository {
  @override
  Future<FamilyLinkCode> fetch() => Future.error(
        const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.unavailable),
      );
}
      
class _FallbackDoseOutbox implements DoseOutbox {
  @override
  Future<LocalDoseLog> enqueue({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) async {
    return LocalDoseLog(
      clientUuid: 'fallback-${DateTime.now().microsecondsSinceEpoch}',
      medicationScheduleId: medicationScheduleId,
      scheduledAt: scheduledAt,
      takenAt: takenAt,
      status: DoseLogStatus.taken,
      syncState: DoseLogSyncState.pendingUpload,
      localUpdatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<LocalDoseLog>> getPendingLogs() async => const [];

  @override
  Future<void> markSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async {}

  @override
  Future<void> markFailed({
    required String clientUuid,
    required String errorMessage,
  }) async {}

  @override
  Stream<DoseLogSyncState?> watchStatus(String clientUuid) =>
      const Stream.empty();

  @override
  Future<void> dispose() async {}
}

class _FallbackReminderScheduler implements ReminderScheduler {
  @override
  Future<void> snooze({
    required int medicationScheduleId,
    required DateTime scheduledAt,
    required DateTime remindAt,
  }) async {}
}
