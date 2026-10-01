import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('start syncs pending dose logs immediately when already online',
      () async {
    final store = _FakeLocalMedicationStore([_doseLog('dose-1')]);
    final remote = _FakeDoseRemoteDataSource();
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(remote.uploadedClientUuids, ['dose-1']);
    expect(store.syncedClientUuids, ['dose-1']);
  });

  test('syncs pending dose logs when connectivity comes back', () async {
    final store = _FakeLocalMedicationStore([_doseLog('dose-1')]);
    final remote = _FakeDoseRemoteDataSource();
    final network = _FakeConnectivityMonitor(isOnline: false);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();
    expect(remote.uploadedClientUuids, isEmpty);

    network.goOnline();
    await engine.syncPendingDoseLogs();

    expect(remote.uploadedClientUuids, ['dose-1']);
    expect(store.syncedClientUuids, ['dose-1']);
  });

  test('retries transient upload failures with bounded backoff', () async {
    final store = _FakeLocalMedicationStore([_doseLog('dose-1')]);
    final remote = _FakeDoseRemoteDataSource(
      failuresBeforeSuccess: 2,
      failure: const ApiException('timeout', isTransient: true),
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final delays = <Duration>[];
    final engine = _engine(
      store: store,
      remote: remote,
      network: network,
      delay: (duration) async => delays.add(duration),
    );

    await engine.start();

    expect(remote.uploadedClientUuids, ['dose-1', 'dose-1', 'dose-1']);
    expect(delays, const [Duration(seconds: 1), Duration(seconds: 3)]);
    expect(store.syncedClientUuids, ['dose-1']);
    expect(store.failedClientUuids, isEmpty);
  });

  test('keeps transient failures pending after max attempts', () async {
    final doseLog = _doseLog('dose-1');
    final store = _FakeLocalMedicationStore([doseLog]);
    final remote = _FakeDoseRemoteDataSource(
      failuresBeforeSuccess: 5,
      failure: const ApiException('offline', isTransient: true),
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(remote.uploadedClientUuids, ['dose-1', 'dose-1', 'dose-1']);
    expect(store.syncedClientUuids, isEmpty);
    expect(store.failedClientUuids, isEmpty);
    expect(await store.getPendingDoseLogs(), [doseLog]);
  });

  test('does not retry non-transient failures', () async {
    final store = _FakeLocalMedicationStore([_doseLog('dose-1')]);
    final remote = _FakeDoseRemoteDataSource(
      failuresBeforeSuccess: 1,
      failure: const ApiException('bad request', statusCode: 400),
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(remote.uploadedClientUuids, ['dose-1']);
    expect(store.syncedClientUuids, isEmpty);
    expect(store.failedClientUuids, ['dose-1']);
  });

  test('does not upload a record again after it is marked synced', () async {
    final store = _FakeLocalMedicationStore([_doseLog('dose-1')]);
    final remote = _FakeDoseRemoteDataSource();
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();
    await engine.syncPendingDoseLogs();

    expect(remote.uploadedClientUuids, ['dose-1']);
    expect(store.syncedClientUuids, ['dose-1']);
  });

  test('DoseApiRemoteDataSource posts backend batch payload and parses json',
      () async {
    late Object? requestBody;
    late String requestPath;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final done = Completer<void>();

    unawaited(
      server.first.then((request) async {
        requestPath = request.uri.path;
        requestBody = jsonDecode(await utf8.decodeStream(request));
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode([
            {
              'client_uuid': 'dose-1',
              'id': 99,
              'synced_at': '2026-09-30T02:00:00.000Z',
            }
          ]),
        );
        await request.response.close();
        done.complete();
      }),
    );

    final remote = DoseApiRemoteDataSource(
      ApiClient(baseUrl: Uri.parse('http://localhost:${server.port}')),
    );

    final results = await remote.uploadDoses([_doseLog('dose-1')]);
    await done.future;
    await server.close(force: true);

    expect(requestPath, '/doses/batch');
    expect(
      requestBody,
      [
        {
          'client_uuid': 'dose-1',
          'schedule_id': 12,
          'scheduled_at': '2026-09-30T01:00:00.000Z',
          'taken_at': '2026-09-30T01:05:00.000Z',
        }
      ],
    );
    expect(results.single.clientUuid, 'dose-1');
    expect(results.single.serverId, 99);
    expect(results.single.syncedAt, DateTime.utc(2026, 9, 30, 2));
  });
}

DoseOutboxSyncEngine _engine({
  required _FakeLocalMedicationStore store,
  required _FakeDoseRemoteDataSource remote,
  required _FakeConnectivityMonitor network,
  SyncDelay delay = _noDelay,
  int batchSize = 10,
}) {
  return DoseOutboxSyncEngine(
    localStore: store,
    remoteDataSource: remote,
    connectivityMonitor: network,
    batchSize: batchSize,
    delay: delay,
    clock: () => DateTime.utc(2026, 9, 30),
  );
}

Future<void> _noDelay(Duration duration) async {}

class _FakeConnectivityMonitor implements ConnectivityMonitor {
  _FakeConnectivityMonitor({required bool isOnline}) : _isOnline = isOnline;

  bool _isOnline;
  final _controller = StreamController<bool>.broadcast();

  void goOnline() {
    _isOnline = true;
    _controller.add(true);
  }

  @override
  Future<bool> get isOnline async => _isOnline;

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  @override
  Future<void> dispose() async => _controller.close();
}

class _FakeDoseRemoteDataSource implements DoseRemoteDataSource {
  _FakeDoseRemoteDataSource({
    this.failuresBeforeSuccess = 0,
    this.failure = const ApiException('temporary', isTransient: true),
  });

  int failuresBeforeSuccess;
  final Object failure;
  final uploadedClientUuids = <String>[];

  @override
  Future<List<DoseUploadResult>> uploadDoses(
      List<LocalDoseLog> doseLogs) async {
    uploadedClientUuids.addAll(doseLogs.map((doseLog) => doseLog.clientUuid));

    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw failure;
    }

    return doseLogs
        .map(
          (doseLog) => DoseUploadResult(
            clientUuid: doseLog.clientUuid,
            serverId: 99,
          ),
        )
        .toList(growable: false);
  }
}

class _FakeLocalMedicationStore implements LocalMedicationStore {
  _FakeLocalMedicationStore(List<LocalDoseLog> doseLogs)
      : _doseLogs = Map.fromEntries(
          doseLogs.map((doseLog) => MapEntry(doseLog.clientUuid, doseLog)),
        );

  final Map<String, LocalDoseLog> _doseLogs;
  final syncedClientUuids = <String>[];
  final failedClientUuids = <String>[];

  @override
  Future<List<LocalDoseLog>> getPendingDoseLogs() async {
    return _doseLogs.values
        .where((doseLog) => doseLog.syncState == DoseLogSyncState.pendingUpload)
        .toList(growable: false);
  }

  @override
  Future<void> markDoseLogSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async {
    syncedClientUuids.add(clientUuid);
    final current = _doseLogs[clientUuid]!;
    _doseLogs[clientUuid] = LocalDoseLog(
      id: serverId,
      clientUuid: current.clientUuid,
      medicationScheduleId: current.medicationScheduleId,
      scheduledAt: current.scheduledAt,
      takenAt: current.takenAt,
      status: current.status,
      syncState: DoseLogSyncState.synced,
      syncedAt: syncedAt,
      localUpdatedAt: current.localUpdatedAt,
    );
  }

  @override
  Future<void> markDoseLogFailed({
    required String clientUuid,
    required String errorMessage,
  }) async {
    failedClientUuids.add(clientUuid);
    final current = _doseLogs[clientUuid]!;
    _doseLogs[clientUuid] = LocalDoseLog(
      id: current.id,
      clientUuid: current.clientUuid,
      medicationScheduleId: current.medicationScheduleId,
      scheduledAt: current.scheduledAt,
      takenAt: current.takenAt,
      status: current.status,
      syncState: DoseLogSyncState.failed,
      lastError: errorMessage,
      localUpdatedAt: current.localUpdatedAt,
    );
  }

  @override
  Future<List<LocalMedicationSchedule>> getActiveSchedules({
    required String patientId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getMeta(String key) {
    throw UnimplementedError();
  }

  @override
  Future<LocalMedicationSchedule?> getScheduleById(int scheduleId) {
    throw UnimplementedError();
  }

  @override
  Future<void> replaceSchedules({
    required String patientId,
    required List<LocalMedicationSchedule> schedules,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setMeta(String key, String value) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertDoseLog(LocalDoseLog doseLog) {
    throw UnimplementedError();
  }
}

LocalDoseLog _doseLog(String clientUuid) {
  return LocalDoseLog(
    clientUuid: clientUuid,
    medicationScheduleId: 12,
    scheduledAt: DateTime.utc(2026, 9, 30, 1),
    takenAt: DateTime.utc(2026, 9, 30, 1, 5),
    status: DoseLogStatus.taken,
    syncState: DoseLogSyncState.pendingUpload,
    localUpdatedAt: DateTime.utc(2026, 9, 30, 1, 5),
  );
}
