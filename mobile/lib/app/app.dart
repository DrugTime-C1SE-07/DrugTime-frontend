import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../features/adherence/domain/repositories/adherence_repository.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import '../features/adherence_history/domain/repositories/adherence_history_repository.dart';
import '../features/adherence_history/presentation/state/adherence_history_controller.dart';
import '../core/notification/device_token_coordinator.dart';
import '../core/notification/family_push_service.dart';
import '../features/family/presentation/state/family_alert_controller.dart';
import '../features/family/presentation/state/family_alert_scope.dart';
import '../features/consent/data/repositories/in_memory_consent_repository.dart';
import '../features/consent/domain/repositories/consent_repository.dart';
import '../features/consent/presentation/state/consent_controller.dart';
import '../features/family/domain/entities/family_link_code.dart';
import '../features/family/domain/entities/family_link_code_failure.dart';
import '../features/family/domain/repositories/family_link_code_repository.dart';
import '../features/family/presentation/state/family_link_code_controller.dart';
import '../core/config/app_config.dart';
import '../features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import '../features/family_link/data/repositories/in_memory_family_link_repository.dart';
import '../features/family_link/data/sources/invite_link_source.dart';
import '../features/family_link/domain/entities/link_code.dart';
import '../features/family_link/domain/repositories/caregiver_repository.dart';
import '../features/family_link/domain/repositories/family_link_repository.dart';
import '../features/family_link/presentation/state/family_link_scope.dart';
import '../features/family_link/presentation/state/incoming_requests_controller.dart';
import '../features/family_link/presentation/state/invite_link_controller.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/repositories/medication_repository.dart';
import '../features/medication/presentation/state/medication_controller.dart';
import '../features/reminder/domain/entities/dose_reminder.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/state/profile_controller.dart';
import 'router.dart';
import 'app_shell.dart';
import '../core/utils/app_assets.dart';
import 'theme/app_theme.dart';
import '../features/medication_capture/data/capture_services.dart';
import '../features/medication_capture/presentation/state/capture_scope.dart';

class DrugTimeApp extends StatefulWidget {
  const DrugTimeApp({
    super.key,
    required this.authController,
    this.adherenceHistoryRepository,
    this.medicationRepository,
    this.adherenceRepository,
    this.consentRepository,
    this.familyLinkCodeRepository,
    this.familyLinkRepository,
    this.caregiverRepository,
    this.inviteLinkSource,
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
    this.captureServices,
    this.initialTab = AppTab.medications,
    this.preview = false,
    this.familyAlertController,
    this.familyPushService,
    this.deviceTokenCoordinator,
    this.familyConnectivity,
  });

  /// Trạng thái đăng nhập; app chạy thật dựng với RemoteAuthRepository (xem main.dart).
  final AuthController authController;
  final AppTab initialTab;
  final bool preview;
  final AdherenceHistoryRepository? adherenceHistoryRepository;
  final FamilyAlertController? familyAlertController;
  final FamilyPushService? familyPushService;
  final DeviceTokenCoordinator? deviceTokenCoordinator;
  final ConnectivityMonitor? familyConnectivity;

  /// Cho phép test/bản build khác thay nguồn dữ liệu thuốc.
  final MedicationRepository? medicationRepository;

  /// Read-only family adherence history; supplied from Backend API on mobile.
  final AdherenceRepository? adherenceRepository;

  /// Không truyền thì dùng consent trong bộ nhớ đã đồng ý `health_data` (vào thẳng Trang chủ).
  final ConsentRepository? consentRepository;

  /// Cho phép test thay nguồn lấy mã liên kết; bản thật dùng Backend API.
  final FamilyLinkCodeRepository? familyLinkCodeRepository;

  /// Gửi yêu cầu theo dõi người thân. Không truyền thì dùng bản trong bộ nhớ (web, test).
  final FamilyLinkRepository? familyLinkRepository;

  /// Duyệt yêu cầu theo dõi và quản lý người giám sát (vai patient). Không truyền thì dùng bản
  /// trong bộ nhớ (web, test).
  final CaregiverRepository? caregiverRepository;

  /// Link mời mở app (Android App Links). Không truyền thì app không nhận link.
  final InviteLinkSource? inviteLinkSource;
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

  /// Ép route đầu (test). Không truyền thì chọn theo phiên đăng nhập.
  final String? initialRoute;

  /// Khóa điều hướng cấp cao nhất; cho phép test hoặc bên ngoài chủ động điều hướng.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Dịch vụ thông báo để tiếp nhận sự kiện click thông báo và điều hướng cold start.
  final NotificationService? notificationService;
  final CaptureServices? captureServices;

  @override
  State<DrugTimeApp> createState() => _DrugTimeAppState();
}

class _DrugTimeAppState extends State<DrugTimeApp> with WidgetsBindingObserver {
  late final CaptureServices _captures =
      widget.captureServices ?? CaptureServices.native();

  StreamSubscription<bool>? _familyConnection;
  final _familyAdherenceAvailability = ValueNotifier<bool>(false);
  String? _tokenSession;
  bool _foreground = true, _online = true, _openingFamily = false;
  Timer? _expiryTimer;
  // Chỉ cho đọc cảnh báo khi phiên, hồ sơ, consent, mạng và foreground đều sẵn sàng.
  bool get _familyReady =>
      _sessionLoaded &&
      _auth.isAuthenticated &&
      !_auth.isSigningOut &&
      !_auth.needsProfile &&
      _consents.isLoaded &&
      _consents.hasHealthData &&
      !_consents.needsTerms &&
      _foreground &&
      _online;
  void _familyChanged() {
    final session = _auth.currentSession;
    final ready = _familyReady;
    _familyAdherenceAvailability.value = ready;
    widget.familyAlertController?.setSession(
        _auth.isAuthenticated ? session?.accessToken : null,
        ready: ready);
    if (_auth.isAuthenticated &&
        !_auth.isSigningOut &&
        _foreground &&
        _online &&
        widget.deviceTokenCoordinator?.blocksRegistration != true &&
        session != null &&
        _tokenSession != session.accessToken) {
      _tokenSession = session.accessToken;
      widget.familyPushService?.allow();
      unawaited(widget.deviceTokenCoordinator
          ?.activate(session)
          .catchError((Object e) {
        if (_auth.currentSession?.accessToken == session.accessToken) {
          _tokenSession = null;
        }
        if (mounted) {
          _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
              content: Text(
                  'Chưa bật được cảnh báo đẩy. Mở lại ứng dụng để thử lại')));
        }
      }));
      _expiryTimer?.cancel();
      _expiryTimer = Timer(session.expiresAt.difference(DateTime.now()), () {
        if (mounted &&
            _auth.currentSession?.accessToken == session.accessToken) {
          unawaited(_auth.handleUnauthorized().catchError((Object _) {}));
        }
      });
    }
    if (!_auth.isAuthenticated) {
      _tokenSession = null;
      _expiryTimer?.cancel();
      if (_wasAuthenticated) widget.familyPushService?.clear();
    }
    if (ready) _openPendingFamily();
  }

  // Tap cold start giữ lại ID tới khi qua các cổng sẵn sàng và navigator đã được dựng.
  void _openPendingFamily() {
    final push = widget.familyPushService;
    if (!_familyReady || push == null || !push.hasPending || _openingFamily) {
      return;
    }
    _openingFamily = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openingFamily = false;
      if (!mounted || !_familyReady || !push.hasPending) return;
      final id = push.pendingId;
      push.consume();
      if (id == null) {
        _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Cảnh báo không còn khả dụng. Vui lòng mở hộp thư')));
      }
      _navigatorKey.currentState?.pushNamed(
          id == null ? AppRoutes.familyAlerts : AppRoutes.familyAlertDetail,
          arguments: id);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Xóa nội dung khỏi RAM khi app ra nền; lần mở lại phải đọc quyền từ server.
    if (!_foreground) widget.familyAlertController?.clear();
    if (_foreground && _auth.currentSession?.isExpired == true) {
      unawaited(_auth.handleUnauthorized().catchError((Object _) {}));
    } else if (_foreground && _auth.isAuthenticated) {
      // Quay lại app: gửi hàng chờ liều và checkpoint (task 3.19).
      unawaited(widget.doseOutboxSyncEngine?.syncNow());
    }
    if (_foreground) {
      unawaited(_incomingRequests.load());
    }
    _familyChanged();
  }

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

  late final FamilyLinkRepository _familyLinks =
      widget.familyLinkRepository ?? InMemoryFamilyLinkRepository();
  late final CaregiverRepository _caregivers =
      widget.caregiverRepository ?? InMemoryCaregiverRepository();
  late final IncomingRequestsController _incomingRequests =
      IncomingRequestsController(_caregivers);
  final InviteLinkController _invites = InviteLinkController();
  StreamSubscription<Uri>? _inviteLinks;

  AuthController get _auth => widget.authController;
  late final AdherenceHistoryController _history = AdherenceHistoryController(
    widget.adherenceHistoryRepository,
    clock: widget.clock,
  );
  late final ProfileController _profiles =
      ProfileController(widget.profileRepository);
  String? _profileUser;
  bool _hadHealthConsent = false;

  void _onConsentChanged() {
    final granted = _consents.hasHealthData;
    if (_hadHealthConsent && !granted) {
      _profiles.revoke();
      _history.revoke();
    }
    if (!_hadHealthConsent && granted) _history.allowFreshRead();
    _hadHealthConsent = granted;
    _familyChanged();
  }

  bool _sessionLoaded = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    if (widget.captureServices != null ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) {
      unawaited(_captures.initialize().catchError((Object e) {
        _captures.cleanupError = 'Chưa khởi tạo được kho ảnh an toàn.';
      }));
    }
    WidgetsBinding.instance.addObserver(this);
    widget.familyPushService?.addListener(_openPendingFamily);
    widget.notificationService?.onFamilyAction =
        (id) => widget.familyPushService?.offer(id == null ? null : '$id');
    final pendingId = widget.notificationService?.consumeFamilyId();
    final invalidFamily =
        widget.notificationService?.consumeInvalidFamilyPayload() ?? false;
    if (pendingId != null) widget.familyPushService?.offer('$pendingId');
    if (invalidFamily) widget.familyPushService?.offer(null);
    _familyConnection =
        widget.familyConnectivity?.onlineChanges.listen((online) {
      _online = online;
      if (!online) widget.familyAlertController?.clear();
      _familyChanged();
    });
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) unawaited(syncEngine.start());
    _auth.addListener(_onAuthChanged);
    _setupNotificationHandling();
    _consents.addListener(_onConsentChanged);
    // Link chỉ được giữ chờ; AppShell mở màn nhập mã khi người dùng đã đăng nhập xong.
    _inviteLinks =
        widget.inviteLinkSource?.links.listen((uri) => _invites.offer(
              code: linkCodeFromInviteUri(uri, host: AppConfig.inviteLinkHost),
            ));
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
    final scheduler = widget.reminderScheduler ?? _FallbackReminderScheduler();

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
    if (_auth.isAuthenticated) {
      unawaited(_medications.load());
      unawaited(_incomingRequests.load());
    }
    _history.setPatient(
        _auth.isAuthenticated ? _auth.currentSession?.userId : null);
    _familyChanged();
  }

  void _onAuthChanged() {
    if (!_sessionLoaded) return;
    _familyChanged();
    final authenticated = _auth.isAuthenticated;
    final user = authenticated ? _auth.currentSession?.userId : null;
    final switchedUser = user != _profileUser;
    if (switchedUser) {
      unawaited(_captures.invalidate());
      _history.setPatient(user);
      _profiles.clear();
      _profileUser = user;
    }
    if (_wasAuthenticated && !authenticated) {
      _medications.clear();
      _consents.clear();
      _familyLinkCode.clear();
      _invites.clear();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else if (!_wasAuthenticated && authenticated) {
      unawaited(_medications.load());
      unawaited(_incomingRequests.load());
      unawaited(widget.doseOutboxSyncEngine?.syncNow());
    } else if (switchedUser && authenticated) {
      _medications.clear();
      _consents.clear();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      unawaited(_medications.load());
      unawaited(_incomingRequests.load());
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
    unawaited(_captures.invalidate());
    if (widget.captureServices == null) _captures.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    unawaited(_familyConnection?.cancel());
    _familyAdherenceAvailability.dispose();
    unawaited(widget.familyConnectivity?.dispose());
    widget.familyPushService?.removeListener(_openPendingFamily);
    widget.notificationService?.onFamilyAction = null;
    unawaited(widget.deviceTokenCoordinator?.dispose());
    _auth.removeListener(_onAuthChanged);
    _consents.removeListener(_onConsentChanged);
    _profiles.dispose();
    _history.dispose();
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) unawaited(syncEngine.dispose());
    _medications.dispose();
    _consents.dispose();
    _familyLinkCode.dispose();
    _incomingRequests.dispose();
    unawaited(_inviteLinks?.cancel());
    _invites.dispose();
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
            child: FamilyLinkScope(
              repository: _familyLinks,
              caregivers: _caregivers,
              invites: _invites,
              incomingRequests: _incomingRequests,
              child: ProfileScope(
                controller: _profiles,
                child: AdherenceHistoryScope(
                  controller: _history,
                  child:
                      _sessionLoaded ? _buildApp() : const _SessionLoadingApp(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Route<dynamic>? _route(RouteSettings settings) => onGenerateRoute(
        settings,
        initialTab: widget.initialTab,
        preview: widget.preview,
        adherenceRepository: widget.adherenceRepository,
        familyAdherenceAvailability: _familyAdherenceAvailability,
      );

  Widget _buildApp() {
    final app = MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'DrugTime',
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          CaptureScope(services: _captures, child: child!),
      theme: buildAppTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: _startRoute,
      navigatorObservers: [familyAdherenceRouteObserver],
      onGenerateRoute: _route,
      // Chỉ dựng đúng một route đầu.
      onGenerateInitialRoutes: (name) => [
        _route(RouteSettings(name: name))!,
      ],
    );
    final alerts = widget.familyAlertController;
    return alerts == null
        ? app
        : FamilyAlertScope(controller: alerts, child: app);
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
