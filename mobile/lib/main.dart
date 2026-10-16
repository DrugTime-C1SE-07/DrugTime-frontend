import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
import 'features/medication/data/repositories/remote_medication_repository.dart';

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

  runApp(DrugTimeApp(
    authController: authController,
    medicationRepository:
        apiClient == null ? null : RemoteMedicationRepository(apiClient),
    consentRepository:
        apiClient == null ? null : RemoteConsentRepository(apiClient),
    doseOutboxSyncEngine:
        apiClient == null ? null : _buildDoseOutboxSyncEngine(apiClient),
    notificationService: notificationService,
  ));
}

ApiClient _buildApiClient(AuthController auth) => ApiClient(
      baseUrl: Uri.parse(AppConfig.apiBaseUrl),
      // Đọc phiên ở mỗi request: đăng xuất là token không còn được gửi.
      authTokenProvider: () async =>
          auth.isAuthenticated ? auth.currentSession?.accessToken : null,
      onUnauthorized: auth.handleUnauthorized,
    );

/// Bộ đồng bộ liều dùng SQLite, không chạy được trên web.
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
