import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/api/api_client.dart';
import 'core/storage/local_db/local_db.dart';
import 'core/storage/local_db/local_medication_store.dart';
import 'core/storage/secure_storage.dart';
import 'core/sync/sync_engine.dart';
import 'app/router.dart';

void main() {
  runApp(
    DrugTimeApp(
      doseOutboxSyncEngine: _buildDoseOutboxSyncEngine(),
      initialRoute: AppRoutes.login,
    ),
  );
}

DoseOutboxSyncEngine? _buildDoseOutboxSyncEngine() {
  const apiBaseUrl = String.fromEnvironment('DRUGTIME_API_BASE_URL');
  if (apiBaseUrl.isEmpty) {
    return null;
  }

  final secureStorage = SecureStorage();
  final localDb = LocalDb(secureStorage);
  final localStore = SqliteLocalMedicationStore(localDb);
  final apiClient = ApiClient(baseUrl: Uri.parse(apiBaseUrl));

  return DoseOutboxSyncEngine(
    localStore: localStore,
    remoteDataSource: DoseApiRemoteDataSource(apiClient),
    connectivityMonitor: PollingConnectivityMonitor(),
  );
}
