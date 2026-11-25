import 'package:flutter/foundation.dart';
import 'features/consent/data/account_deletion_repository.dart';
import 'features/consent/data/account_deletion_status_store.dart';
import 'features/patient_monitor/data/patient_monitor_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notification/device_token_coordinator.dart';
import 'core/notification/device_token_store.dart';
import 'core/notification/family_push_service.dart';
import 'features/meal_suggestion/data/meal_choice_store.dart';
import 'features/meal_suggestion/data/meal_widget_bridge.dart';
import 'features/meal_suggestion/data/repositories/remote_allergy_profile_repository.dart';
import 'features/meal_suggestion/data/repositories/remote_meal_suggestion_repository.dart';
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
import 'core/notification/reminder_sound_controller.dart';
import 'core/notification/reminder_sound_native.dart';
import 'core/notification/reminder_sound_store.dart';
import 'core/notification/reminder_sync_coordinator.dart';
import 'core/storage/local_db/local_medication_store.dart';
import 'core/storage/local_db/sqlite_dose_outbox.dart';
import 'core/storage/secure_storage.dart';
import 'core/sync/api_schedule_remote_data_source.dart';
import 'core/sync/schedule_sync_service.dart';
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
import 'features/medication_capture/data/ocr_api_repository.dart';
import 'features/interaction_check/data/repositories/remote_interaction_check_repository.dart';
import 'features/profile/data/repositories/profile_repository_provider.dart';
import 'features/profile/data/repositories/remote_health_setup_repository.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/app_lock_settings_store.dart';
import 'core/security/device_authenticator.dart';

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

  // Âm nhắc người dùng chọn ở S08-4a; mỗi âm một Android channel.
  final reminderSounds = ReminderSoundController(
    store: SecureReminderSoundStore(),
    native: MethodChannelReminderSoundNative(),
    notifications: notificationService.platform,
    targetPlatform: defaultTargetPlatform,
    onLog: debugPrint,
  );

  // Khởi tạo dịch vụ lên lịch thông báo nhắc uống thuốc
  final scheduler = ReminderNotificationScheduler(
    platform: notificationService.platform,
    location: notificationService.location,
    targetPlatform: defaultTargetPlatform,
    soundChannel: () => reminderSounds.selected,
  );

  final deletionStatusStore = SecureAccountDeletionStatusStore(secureStorage);
  final accountDeletionRecheck = ValueNotifier<int>(0);
  final apiClient = _buildApiClient(
    authController,
    onAccountPendingDeletion: () => accountDeletionRecheck.value++,
  );

  // Lịch uống lấy từ API về máy rồi mới lập nhắc; chạy khi có phiên (app.dart) và khi sửa thuốc.
  final reminderSync = ReminderSyncCoordinator(
    syncService: ScheduleSyncService(
      remoteDataSource: ApiScheduleRemoteDataSource(apiClient),
      localStore: localStore,
    ),
    localStore: localStore,
    scheduler: scheduler,
    onLog: debugPrint,
    beforeSchedule: reminderSounds.ensureValid,
  );

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
    showReminderForeground: (id, body) async {
      if (authController.isAuthenticated && !authController.isSigningOut) {
        await notificationService.showReceivedReminder(id, body);
      }
    },
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
    await deletionStatusStore.clear(session.userId);
    await reminderSync.clear();
    // Q1: âm tự thêm thuộc thiết bị của người dùng vừa đăng xuất.
    try {
      await reminderSounds.clearAll();
    } on Exception catch (e) {
      debugPrint('Không xóa được âm nhắc tự thêm: $e');
    }
    await tokens?.logout(session);
  };

  authController.onSessionExpired = () async {
    alerts.clear();
    push.clear();
    await deletionStatusStore.clearAll();
    await tokens?.expire();
  };

  final profileRepository =
      createProfileRepository(apiClient, previewMode: false);

  runApp(DrugTimeApp(
    authController: authController,
    appLockController: AppLockController(
      store: SecureAppLockSettingsStore(),
      authenticator: LocalDeviceAuthenticator(),
    ),
    accountDeletionRepository: RemoteAccountDeletionRepository(apiClient),
    accountDeletionStatusStore: deletionStatusStore,
    accountDeletionRecheck: accountDeletionRecheck,
    familyAlertController: alerts,
    familyPushService: push,
    deviceTokenCoordinator: tokens,
    familyConnectivity: PollingConnectivityMonitor(),
    patientMonitorRepository: PatientMonitorRepository(apiClient),
    scheduleSource: ApiScheduleRemoteDataSource(apiClient),
    adherenceHistoryRepository: RemoteAdherenceHistoryRepository(apiClient),
    adherenceRepository: RemoteAdherenceRepository(apiClient),
    medicationRepository: RemoteMedicationRepository(apiClient),
    ocrMatchingRepository: RemoteOcrMatchingRepository(apiClient),
    interactionCheckRepository: RemoteInteractionCheckRepository(apiClient),
    consentRepository: RemoteConsentRepository(apiClient),
    doseOutboxSyncEngine: doseSync,
    localMedicationStore: localStore,
    doseOutbox: doseOutbox,
    reminderScheduler: scheduler,
    reminderSyncCoordinator: reminderSync,
    reminderSoundController: reminderSounds,
    shouldAskReminderPermissions: secureStorage.markReminderPermissionsAsked,
    familyLinkCodeRepository: RemoteFamilyLinkCodeRepository(apiClient),
    familyLinkRepository: RemoteFamilyLinkRepository(apiClient),
    caregiverRepository: RemoteCaregiverRepository(apiClient),
    inviteLinkSource: AppLinksInviteLinkSource(),
    notificationService: notificationService,
    profileRepository: profileRepository,
    healthSetupRepository: RemoteHealthSetupRepository(apiClient),
    mealSuggestionRepository: RemoteMealSuggestionRepository(apiClient),
    // Hồ sơ dị ứng thật từ `GET /profile/health-setup` (task adhoc-20261118-health-profile-catalog).
    allergyProfileRepository: RemoteAllergyProfileRepository(apiClient),
    mealChoiceStore: SecureMealChoiceStore(),
    // Widget "Thực đơn hôm nay" chỉ có trên Android (iOS ngoài phạm vi).
    mealWidgetBridge: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? HomeWidgetMealBridge()
        : null,
    mealWidgetLinkSource:
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? HomeWidgetMealLinkSource()
            : null,
  ));
}

ApiClient _buildApiClient(
  AuthController auth, {
  AccountPendingDeletionHandler? onAccountPendingDeletion,
}) =>
    ApiClient(
      baseUrl: Uri.parse(AppConfig.apiBaseUrl),
      // Đọc phiên ở mỗi request: đăng xuất là token không còn được gửi.
      authTokenProvider: () async =>
          auth.isAuthenticated ? auth.currentSession?.accessToken : null,
      onUnauthorized: auth.handleUnauthorized,
      onAccountPendingDeletion: onAccountPendingDeletion,
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
