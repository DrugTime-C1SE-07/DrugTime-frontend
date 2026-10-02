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
import 'features/auth/presentation/state/auth_controller.dart';

void main() {
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

  runApp(DrugTimeApp(
    authController: authController,
    doseOutboxSyncEngine: _buildDoseOutboxSyncEngine(authController),
  ));
}

/// Bộ đồng bộ liều dùng SQLite và `dart:io` (`HttpClient`), không chạy được trên web:
/// bản web (dùng để xem thử giao diện) bỏ qua đồng bộ liều ngoại tuyến.
DoseOutboxSyncEngine? _buildDoseOutboxSyncEngine(AuthController auth) {
  if (kIsWeb) return null;
  final secureStorage = SecureStorage();
  final localDb = LocalDb(secureStorage);
  final localStore = SqliteLocalMedicationStore(localDb);
  final apiClient = ApiClient(
    baseUrl: Uri.parse(AppConfig.apiBaseUrl),
    // Đọc phiên ở mỗi request: đăng xuất là token không còn được gửi.
    authTokenProvider: () async => auth.isAuthenticated ? auth.currentSession?.accessToken : null,
    onUnauthorized: auth.handleUnauthorized,
  );

  return DoseOutboxSyncEngine(
    localStore: localStore,
    remoteDataSource: DoseApiRemoteDataSource(apiClient),
    connectivityMonitor: PollingConnectivityMonitor(),
  );
}
