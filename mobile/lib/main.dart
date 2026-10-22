import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notification/device_token_coordinator.dart';
import 'core/notification/device_token_store.dart';
import 'core/notification/family_push_service.dart';
import 'features/family/data/repositories/remote_family_alert_repository.dart';
import 'features/family/presentation/state/family_alert_controller.dart';

import 'app/app.dart';
import 'app/missing_config_app.dart';
import 'core/api/api_client.dart';
import 'core/config/app_config.dart';
import 'core/storage/local_db/local_db.dart';
import 'core/storage/local_db/local_medication_store.dart';
import 'core/storage/secure_storage.dart';
import 'core/sync/sync_engine.dart';
import 'features/auth/data/repositories/remote_auth_repository.dart';
import 'features/auth/data/sources/auth_api_service.dart';
import 'features/auth/data/sources/auth_session_store.dart';
import 'core/notification/notification_service.dart';
import 'features/auth/presentation/state/auth_controller.dart';
import 'features/consent/data/repositories/remote_consent_repository.dart';
import 'features/family/data/repositories/remote_family_link_code_repository.dart';
import 'features/family_link/data/repositories/remote_family_link_repository.dart';
import 'features/family_link/data/sources/invite_link_source.dart';
import 'features/medication/data/repositories/remote_medication_repository.dart';
import 'features/profile/data/repositories/profile_preview_repository.dart';
import 'features/profile/data/repositories/profile_repository_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const MissingConfigApp());
    return;
  }

  final authRepository = RemoteAuthRepository(
    apiService: AuthApiService(baseUrl: AppConfig.apiBaseUrl),
    sessionStore: SecureAuthSessionStore(),
  );

  final authController = AuthController(authRepository);
  final notificationService = NotificationService();
  await notificationService.init();

  // ApiClient dùng `dart:io` (`HttpClient`), không chạy được trên web: bản web (chỉ để xem thử
  // giao diện) dùng thuốc mẫu trong bộ nhớ và bỏ qua đồng bộ liều ngoại tuyến.
  final apiClient = kIsWeb ? null : _buildApiClient(authController);
  final alerts = apiClient == null
      ? null
      : FamilyAlertController(RemoteFamilyAlertRepository(apiClient));
  // Android dùng FCM; nền tảng có API client vẫn đọc được hộp thư qua REST.
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final pushEnabled = android && await initializeFamilyFirebase();
  final push = FamilyPushService(
      android: pushEnabled,
      showForeground: (id, body) async {
        if (authController.isAuthenticated && !authController.isSigningOut) {
          await notificationService.showFamily(id, body);
        }
      });
  DeviceTokenCoordinator? tokens;
  if (pushEnabled) {
    FirebaseMessaging.onBackgroundMessage(familyPushBackgroundHandler);
    // Token creation is explicitly controlled by the authenticated lifecycle.
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    tokens = DeviceTokenCoordinator(
        messaging: AndroidFamilyMessaging(),
        store: SecureDeviceTokenStore(),
        // Client cleanup giữ bearer cố định, không lấy token của tài khoản mới.
        clientForSession: (session) => ApiClient(
            baseUrl: Uri.parse(AppConfig.apiBaseUrl),
            authTokenProvider: () async => session.accessToken),
        clearHealth: () {
          alerts?.clear();
          push.clear();
        },
        clearNotifications: notificationService.clearFamily);
    await push.start();
  }
  authController.beforeSignOut = (session) async {
    alerts?.clear();
    push.clear();
    await tokens?.logout(session);
  };
  authController.onSessionExpired = () async {
    alerts?.clear();
    push.clear();
    await tokens?.expire();
  };

  // PROFILE_PREVIEW=true bypasses only the profile API for local UI review.
  // Run without that dart-define to reconnect profile screens to the backend.
  final profileRepository = apiClient == null
      ? ProfilePreviewRepository()
      : createProfileRepository(apiClient);

  runApp(DrugTimeApp(
    authController: authController,
    familyAlertController: alerts,
    familyPushService: push,
    deviceTokenCoordinator: tokens,
    familyConnectivity: kIsWeb ? null : PollingConnectivityMonitor(),
    medicationRepository:
        apiClient == null ? null : RemoteMedicationRepository(apiClient),
    consentRepository:
        apiClient == null ? null : RemoteConsentRepository(apiClient),
    doseOutboxSyncEngine:
        apiClient == null ? null : _buildDoseOutboxSyncEngine(apiClient),
    familyLinkCodeRepository:
        apiClient == null ? null : RemoteFamilyLinkCodeRepository(apiClient),
    familyLinkRepository:
        apiClient == null ? null : RemoteFamilyLinkRepository(apiClient),
    inviteLinkSource: kIsWeb ? null : AppLinksInviteLinkSource(),
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

DoseOutboxSyncEngine _buildDoseOutboxSyncEngine(ApiClient apiClient) {
  final secureStorage = SecureStorage();
  final localDb = LocalDb(secureStorage);
  final localStore = SqliteLocalMedicationStore(localDb);
  return DoseOutboxSyncEngine(
    localStore: localStore,
    remoteDataSource: DoseApiRemoteDataSource(apiClient),
    connectivityMonitor: PollingConnectivityMonitor(),
  );
}
