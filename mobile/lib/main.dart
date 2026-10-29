import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notification/device_token_coordinator.dart';
import 'core/notification/device_token_store.dart';
import 'core/notification/family_push_service.dart';
import 'features/family/data/repositories/remote_family_alert_repository.dart';
import 'features/family/presentation/state/family_alert_controller.dart';

import 'app/app.dart';
import 'app/adherence_demo_app.dart';
import 'app/missing_config_app.dart';
import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'core/storage/local_db/local_db.dart';
import 'core/contracts/dose_outbox.dart';
import 'core/notification/reminder_notification_scheduler.dart';
import 'core/notification/reminder_occurrence_generator.dart';
import 'core/storage/local_db/local_medication_store.dart';
import 'core/storage/local_db/sqlite_dose_outbox.dart';
import 'core/storage/secure_storage.dart';
import 'core/sync/sync_engine.dart';
import 'features/auth/data/repositories/remote_auth_repository.dart';
import 'features/adherence_history/data/repositories/remote_adherence_history_repository.dart';
import 'features/adherence/data/repositories/remote_adherence_repository.dart';
import 'features/auth/data/sources/auth_api_service.dart';
import 'features/auth/data/sources/auth_session_store.dart';
import 'core/notification/notification_service.dart';
import 'features/auth/presentation/state/auth_controller.dart';
import 'features/consent/data/repositories/remote_consent_repository.dart';
import 'features/family/data/repositories/remote_family_link_code_repository.dart';
import 'features/family_link/data/repositories/remote_caregiver_repository.dart';
import 'features/family_link/data/repositories/remote_family_link_repository.dart';
import 'features/family_link/data/sources/invite_link_source.dart';
import 'features/medication/data/repositories/remote_medication_repository.dart';
import 'features/profile/data/repositories/profile_repository_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.previewEnabled) {
    runApp(const AdherenceDemoApp());
    return;
  }
  if (!AppConfig.isConfigured) {
    runApp(const MissingConfigApp());
    return;
  }

  if (kIsWeb) {
    runApp(const MaterialApp(
        home: Scaffold(
            body: SafeArea(
                child: Center(
      child: Text('Chế độ Backend chưa hỗ trợ web. Hãy chạy trên Android.'),
    )))));
    return;
  }
  final authRepository = RemoteAuthRepository(
    apiService: AuthApiService(baseUrl: AppConfig.apiBaseUrl),
    sessionStore: SecureAuthSessionStore(),
  );

  final authController = AuthController(authRepository);
  final notificationService = NotificationService();
  await notificationService.init();

  // Khởi tạo cơ sở dữ liệu cục bộ và hàng đợi outbox (Task 2.07 & 2.24)
  final secureStorage = SecureStorage();
  final localDb = LocalDb(secureStorage);
  final localStore = SqliteLocalMedicationStore(localDb);
  final doseOutbox = SqliteDoseOutbox(localDb: localDb);

  // Khởi tạo dịch vụ lên lịch thông báo nhắc uống thuốc
  final scheduler = ReminderNotificationScheduler(
    platform: notificationService.platform,
    location: notificationService.location,
    targetPlatform: defaultTargetPlatform,
  );

  // Quét và lập lịch lại toàn bộ các đơn thuốc đang kích hoạt khi khởi động ứng dụng
  if (!kIsWeb) {
    try {
      final activeSchedules = await localStore.getActiveSchedules();
      if (activeSchedules.isNotEmpty) {
        final now = DateTime.now().toUtc();
        final occurrences = generateOccurrences(
          schedules: activeSchedules,
          from: now,
          to: now.add(const Duration(days: 7)),
        );
        await scheduler.scheduleOccurrences(occurrences);
      }
    } catch (e) {
      debugPrint('Lỗi quét lập lịch lại đơn thuốc khi khởi động: $e');
    }
  }

  final apiClient = _buildApiClient(authController);

  final alerts = FamilyAlertController(RemoteFamilyAlertRepository(apiClient));

  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final pushEnabled = android && await initializeFamilyFirebase();
  final doseSync = _buildDoseOutboxSyncEngine(
    apiClient,
    authController,
    localStore,
    doseOutbox,
  );

  final push = FamilyPushService(
    android: pushEnabled,
    showForeground: (id, body) async {
      if (authController.isAuthenticated && !authController.isSigningOut) {
        await notificationService.showFamily(id, body);
      }
    },
    onSyncRequest: doseSync.syncNow,
  );

  DeviceTokenCoordinator? tokens;

  if (pushEnabled) {
    FirebaseMessaging.onBackgroundMessage(familyPushBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(false);

    tokens = DeviceTokenCoordinator(
      messaging: AndroidFamilyMessaging(),
      store: SecureDeviceTokenStore(),
      clientForSession: (session) => ApiClient(
        baseUrl: Uri.parse(AppConfig.apiBaseUrl),
        authTokenProvider: () async => session.accessToken,
      ),
      clearHealth: () {
        alerts.clear();
        push.clear();
      },
      clearNotifications: notificationService.clearFamily,
    );

    await push.start();
  }

  authController.beforeSignOut = (session) async {
    alerts.clear();
    push.clear();
    await tokens?.logout(session);
  };

  authController.onSessionExpired = () async {
    alerts.clear();
    push.clear();
    await tokens?.expire();
  };

  final profileRepository =
      createProfileRepository(apiClient, previewMode: false);

  runApp(DrugTimeApp(
    authController: authController,
    familyAlertController: alerts,
    familyPushService: push,
    deviceTokenCoordinator: tokens,
    familyConnectivity: PollingConnectivityMonitor(),
    adherenceHistoryRepository: RemoteAdherenceHistoryRepository(apiClient),
    adherenceRepository: RemoteAdherenceRepository(apiClient),
    medicationRepository: RemoteMedicationRepository(apiClient),
    consentRepository: RemoteConsentRepository(apiClient),
    doseOutboxSyncEngine: doseSync,
    localMedicationStore: localStore,
    doseOutbox: doseOutbox,
    reminderScheduler: scheduler,
    familyLinkCodeRepository: RemoteFamilyLinkCodeRepository(apiClient),
    familyLinkRepository: RemoteFamilyLinkRepository(apiClient),
    caregiverRepository: RemoteCaregiverRepository(apiClient),
    inviteLinkSource: AppLinksInviteLinkSource(),
    notificationService: notificationService,
    profileRepository: profileRepository,
  ));
}

ApiClient _buildApiClient(AuthController auth) => ApiClient(
      baseUrl: Uri.parse(AppConfig.apiBaseUrl),
      // Đọc phiên ở mỗi request: đăng xuất là token không còn được gửi.
      authTokenProvider: () async =>
          auth.isAuthenticated ? auth.currentSession?.accessToken : null,
      onUnauthorized: auth.handleUnauthorized,
    );

DoseOutboxSyncEngine _buildDoseOutboxSyncEngine(
  ApiClient apiClient,
  AuthController auth,
  LocalMedicationStore localStore,
  DoseOutbox doseOutbox,
) {
  return DoseOutboxSyncEngine(
    localStore: localStore,
    outbox: doseOutbox,
    remoteDataSource: DoseApiRemoteDataSource(apiClient),
    connectivityMonitor: PollingConnectivityMonitor(),
    checkpointSource: ApiDoseSyncCheckpointSource(
      apiClient,
      isSignedIn: () => auth.isAuthenticated && !auth.isSigningOut,
    ),
  );
}
