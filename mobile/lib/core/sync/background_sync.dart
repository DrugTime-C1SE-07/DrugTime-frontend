import '../../features/auth/data/sources/auth_session_store.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../storage/local_db/local_db.dart';
import '../storage/local_db/local_medication_store.dart';
import '../storage/secure_storage.dart';
import 'sync_engine.dart';

typedef BackgroundApiClientBuilder = ApiClient Function(String accessToken);
typedef BackgroundSyncEngineBuilder = DoseOutboxSyncEngine Function(
    ApiClient client);

/// Xử lý push `sync_request` khi app chạy nền (task 3.19, Android): gửi hàng chờ liều rồi gửi
/// checkpoint theo đúng quy tắc của [DoseOutboxSyncEngine]. Không hiện thông báo, không đọc hay
/// lưu dữ liệu nào khác. Không có phiên hợp lệ thì bỏ qua; 401 thì dừng mà không gửi checkpoint
/// và không xóa phiên ở isolate nền (app chính tự xử lý khi mở lại).
Future<bool> runBackgroundSync({
  AuthSessionStore? sessionStore,
  BackgroundApiClientBuilder? buildClient,
  BackgroundSyncEngineBuilder? buildEngine,
  DateTime Function()? now,
}) async {
  final session = await (sessionStore ?? SecureAuthSessionStore()).read();
  final at = (now ?? DateTime.now)();
  if (session == null || !at.isBefore(session.expiresAt)) {
    return false;
  }

  final client = (buildClient ?? _defaultClient)(session.accessToken);
  final engine = (buildEngine ?? _defaultEngine)(client);
  try {
    return await engine.syncNow();
  } finally {
    await engine.dispose();
  }
}

ApiClient _defaultClient(String accessToken) => ApiClient(
      baseUrl: Uri.parse(AppConfig.apiBaseUrl),
      authTokenProvider: () async => accessToken,
    );

DoseOutboxSyncEngine _defaultEngine(ApiClient client) => DoseOutboxSyncEngine(
      localStore: SqliteLocalMedicationStore(LocalDb(SecureStorage())),
      remoteDataSource: DoseApiRemoteDataSource(client),
      connectivityMonitor: PollingConnectivityMonitor(),
      checkpointSource: ApiDoseSyncCheckpointSource(client),
    );
