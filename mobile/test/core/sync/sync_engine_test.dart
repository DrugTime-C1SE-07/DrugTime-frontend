import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test('keeps top-level unauthorized batch pending', () async {
    final doseLog = _doseLog('dose-1');
    final store = _FakeLocalMedicationStore([doseLog]);
    final remote = _FakeDoseRemoteDataSource(
      failuresBeforeSuccess: 1,
      failure: const ApiException('unauthorized', statusCode: 401),
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(remote.uploadedClientUuids, ['dose-1']);
    expect(store.syncedClientUuids, isEmpty);
    expect(store.failedClientUuids, isEmpty);
    expect(await store.getPendingDoseLogs(), [doseLog]);
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

  test('syncs successful dose results without rolling back failed item',
      () async {
    final doseLogs = List.generate(10, (index) => _doseLog('dose-$index'));
    final failedDose = doseLogs.last;
    final store = _FakeLocalMedicationStore(doseLogs);
    final remote = _FakeDoseRemoteDataSource(
      results: [
        for (final doseLog in doseLogs.take(9))
          DoseUploadResult(
            clientUuid: doseLog.clientUuid,
            serverId: 9000 + doseLogs.indexOf(doseLog),
            syncedAt: DateTime.utc(2026, 9, 30, 2),
          ),
        DoseUploadResult(
          clientUuid: failedDose.clientUuid,
          status: DoseUploadResultStatus.failed,
          errorCode: 'taken_at_out_of_window',
          errorMessage: 'taken_at_out_of_window: outside allowed window',
        ),
      ],
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(
      store.syncedClientUuids,
      doseLogs.take(9).map((doseLog) => doseLog.clientUuid).toList(),
    );
    expect(store.failedClientUuids, [failedDose.clientUuid]);
    expect(store.errorMessages[failedDose.clientUuid],
        'taken_at_out_of_window: outside allowed window');
    expect(await store.getPendingDoseLogs(), isEmpty);
  });

  test('keeps dose logs pending when batch response omits their client uuid',
      () async {
    final dose1 = _doseLog('dose-1');
    final dose2 = _doseLog('dose-2');
    final store = _FakeLocalMedicationStore([dose1, dose2]);
    final remote = _FakeDoseRemoteDataSource(
      results: const [DoseUploadResult(clientUuid: 'dose-1', serverId: 99)],
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(store.syncedClientUuids, ['dose-1']);
    expect(store.failedClientUuids, isEmpty);
    expect(await store.getPendingDoseLogs(), [dose2]);
  });

  test('does not treat empty batch response as full success', () async {
    final doseLog = _doseLog('dose-1');
    final store = _FakeLocalMedicationStore([doseLog]);
    final remote = _FakeDoseRemoteDataSource(results: const []);
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(store.syncedClientUuids, isEmpty);
    expect(store.failedClientUuids, isEmpty);
    expect(await store.getPendingDoseLogs(), [doseLog]);
  });

  test('ignores response item whose client uuid was not uploaded in batch',
      () async {
    final doseLog = _doseLog('dose-1');
    final store = _FakeLocalMedicationStore([doseLog]);
    final remote = _FakeDoseRemoteDataSource(
      results: const [
        DoseUploadResult(clientUuid: 'dose-1', serverId: 99),
        DoseUploadResult(clientUuid: 'stray-dose', serverId: 100),
      ],
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();

    expect(store.syncedClientUuids, ['dose-1']);
    expect(store.failedClientUuids, isEmpty);
    expect(store.containsClientUuid('stray-dose'), isFalse);
  });

  test('does not re-upload dose log after item-level failed state', () async {
    final store = _FakeLocalMedicationStore([_doseLog('dose-1')]);
    final remote = _FakeDoseRemoteDataSource(
      results: const [
        DoseUploadResult(
          clientUuid: 'dose-1',
          status: DoseUploadResultStatus.failed,
          errorCode: 'invalid_item',
          errorMessage: 'invalid_item',
        ),
      ],
    );
    final network = _FakeConnectivityMonitor(isOnline: true);
    final engine = _engine(store: store, remote: remote, network: network);

    await engine.start();
    await engine.syncPendingDoseLogs();

    expect(remote.uploadedClientUuids, ['dose-1']);
    expect(store.failedClientUuids, ['dose-1']);
    expect(await store.getPendingDoseLogs(), isEmpty);
  });

  test('preserves client uuid when the same scheduled dose is upserted locally',
      () async {
    final original = _doseLog('dose-1');
    final replacement = _doseLog('dose-2');
    final store = _FakeLocalMedicationStore([original]);

    await store.upsertDoseLog(replacement);

    expect(store.containsClientUuid('dose-1'), isTrue);
    expect(store.containsClientUuid('dose-2'), isFalse);
    expect((await store.getPendingDoseLogs()).single.clientUuid, 'dose-1');
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

  test('DoseApiRemoteDataSource parses contract batch item success and failure',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final done = Completer<void>();

    unawaited(
      server.first.then((request) async {
        await utf8.decodeStream(request);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'items': [
              {
                'client_uuid': 'dose-1',
                'result': 'synced',
                'dose_log_id': 9001,
                'synced_at': '2026-09-30T02:00:00.000Z',
              },
              {
                'client_uuid': 'dose-2',
                'result': 'failed',
                'error': {
                  'code': 'taken_at_out_of_window',
                  'detail': 'taken_at must be within 1 hour of scheduled_at',
                },
              },
            ],
          }),
        );
        await request.response.close();
        done.complete();
      }),
    );

    final remote = DoseApiRemoteDataSource(
      ApiClient(baseUrl: Uri.parse('http://localhost:${server.port}')),
    );

    final results = await remote.uploadDoses([
      _doseLog('dose-1'),
      _doseLog('dose-2'),
    ]);
    await done.future;
    await server.close(force: true);

    expect(results, hasLength(2));
    expect(results.first.clientUuid, 'dose-1');
    expect(results.first.isSynced, isTrue);
    expect(results.first.serverId, 9001);
    expect(results.first.syncedAt, DateTime.utc(2026, 9, 30, 2));
    expect(results.last.clientUuid, 'dose-2');
    expect(results.last.isFailed, isTrue);
    expect(results.last.errorCode, 'taken_at_out_of_window');
    expect(
      results.last.errorMessage,
      'taken_at_out_of_window: taken_at must be within 1 hour of scheduled_at',
    );
  });
  group('sync checkpoint (3.19, AC15)', () {
    test('checkpoint after all final results', () async {
      final store = _FakeLocalMedicationStore(
          [_doseLog('dose-1'), _doseLog('dose-2'), _doseLog('dose-3')]);
      final checkpoints = _FakeCheckpointSource();
      final engine = _engine(
        store: store,
        remote: _FakeDoseRemoteDataSource(),
        network: _FakeConnectivityMonitor(isOnline: true),
        checkpoints: checkpoints,
      );

      expect(await engine.syncPendingDoseLogs(), isTrue);

      expect(store.syncedClientUuids, ['dose-1', 'dose-2', 'dose-3']);
      expect(checkpoints.calls, 1);
    });

    for (final status in [404, 409, 422]) {
      test('$status item failure counts as final', () async {
        final checkpoints = _FakeCheckpointSource();
        final engine = _engine(
          store: _FakeLocalMedicationStore([_doseLog('dose-1')]),
          remote: _FakeDoseRemoteDataSource(results: [
            DoseUploadResult(
              clientUuid: 'dose-1',
              status: DoseUploadResultStatus.failed,
              errorCode: 'final',
              httpStatus: status,
            ),
          ]),
          network: _FakeConnectivityMonitor(isOnline: true),
          checkpoints: checkpoints,
        );

        expect(await engine.syncPendingDoseLogs(), isTrue);
        expect(checkpoints.calls, 1);
      });
    }

    test('403 item failure is not final', () async {
      final checkpoints = _FakeCheckpointSource();
      final engine = _engine(
        store: _FakeLocalMedicationStore([_doseLog('dose-1')]),
        remote: _FakeDoseRemoteDataSource(results: const [
          DoseUploadResult(
            clientUuid: 'dose-1',
            status: DoseUploadResultStatus.failed,
            errorCode: 'forbidden_schedule',
            httpStatus: 403,
          ),
        ]),
        network: _FakeConnectivityMonitor(isOnline: true),
        checkpoints: checkpoints,
      );

      expect(await engine.syncPendingDoseLogs(), isFalse);
      expect(checkpoints.calls, 0);
    });

    for (final failure in const [
      ApiException('offline', isTransient: true),
      ApiException('server', statusCode: 500, isTransient: true),
      ApiException('timeout', statusCode: 408, isTransient: true),
      ApiException('throttled', statusCode: 429, isTransient: true),
      ApiException('unauthorized', statusCode: 401),
      ApiException('forbidden', statusCode: 403),
    ]) {
      test('no checkpoint on ${failure.statusCode ?? 'network'} failure',
          () async {
        final checkpoints = _FakeCheckpointSource();
        final engine = _engine(
          store: _FakeLocalMedicationStore([_doseLog('dose-1')]),
          remote: _FakeDoseRemoteDataSource(
              failuresBeforeSuccess: 5, failure: failure),
          network: _FakeConnectivityMonitor(isOnline: true),
          checkpoints: checkpoints,
        );

        expect(await engine.syncPendingDoseLogs(), isFalse);
        expect(checkpoints.calls, 0);
      });
    }

    test('checkpoint when outbox empty, on start and syncNow', () async {
      final checkpoints = _FakeCheckpointSource();
      final remote = _FakeDoseRemoteDataSource();
      final engine = _engine(
        store: _FakeLocalMedicationStore(const []),
        remote: remote,
        network: _FakeConnectivityMonitor(isOnline: true),
        checkpoints: checkpoints,
      );

      await engine.start();
      expect(await engine.syncNow(), isTrue);

      expect(remote.uploadedClientUuids, isEmpty);
      expect(checkpoints.calls, 2);
    });

    test('no checkpoint while offline; checkpoint when network returns',
        () async {
      final checkpoints = _FakeCheckpointSource();
      final network = _FakeConnectivityMonitor(isOnline: false);
      final engine = _engine(
        store: _FakeLocalMedicationStore(const []),
        remote: _FakeDoseRemoteDataSource(),
        network: network,
        checkpoints: checkpoints,
      );

      await engine.start();
      expect(checkpoints.calls, 0);

      network.goOnline();
      await Future<void>.delayed(Duration.zero);
      await engine.syncPendingDoseLogs();
      expect(checkpoints.calls, greaterThanOrEqualTo(1));
    });

    test('periodic 15 minutes while app is open', () async {
      final checkpoints = _FakeCheckpointSource();
      final timers = _FakeTimers();
      final engine = _engine(
        store: _FakeLocalMedicationStore(const []),
        remote: _FakeDoseRemoteDataSource(),
        network: _FakeConnectivityMonitor(isOnline: true),
        checkpoints: checkpoints,
        periodicTimer: timers.create,
      );

      await engine.start();
      expect(timers.intervals, [const Duration(minutes: 15)]);
      expect(checkpoints.calls, 1);

      timers.fire();
      await engine.syncPendingDoseLogs();
      expect(checkpoints.calls, greaterThanOrEqualTo(2));

      await engine.dispose();
      expect(timers.cancelled, isTrue);
    });

    test('checkpoint failure is retried on next sync', () async {
      final checkpoints = _FakeCheckpointSource(failures: 1);
      final engine = _engine(
        store: _FakeLocalMedicationStore(const []),
        remote: _FakeDoseRemoteDataSource(),
        network: _FakeConnectivityMonitor(isOnline: true),
        checkpoints: checkpoints,
      );

      expect(await engine.syncPendingDoseLogs(), isTrue);
      expect(await engine.syncPendingDoseLogs(), isTrue);
      expect(checkpoints.calls, 2);
    });

    test('DoseApiRemoteDataSource parses item http_status', () async {
      final client = ApiClient(
        baseUrl: Uri.parse('https://api.example.test/'),
        httpClient: MockClient((request) async => http.Response(
              jsonEncode({
                'items': [
                  {
                    'client_uuid': 'dose-1',
                    'result': 'failed',
                    'error': {
                      'code': 'schedule_not_found',
                      'http_status': 404,
                      'detail': 'schedule_id was not found',
                    },
                  },
                ],
                'summary': {'total': 1, 'synced': 0, 'failed': 1},
              }),
              200,
            )),
      );

      final results = await DoseApiRemoteDataSource(client)
          .uploadDoses([_doseLog('dose-1')]);

      expect(results.single.isFailed, isTrue);
      expect(results.single.httpStatus, 404);
    });

    test('ApiDoseSyncCheckpointSource posts without body', () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: Uri.parse('https://api.example.test/'),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await ApiDoseSyncCheckpointSource(client).recordCheckpoint();

      expect(captured.method, 'POST');
      expect(captured.url.path, '/doses/sync-checkpoints');
      expect(captured.body, isEmpty);
      expect(captured.headers.containsKey('Content-Type'), isFalse);
    });
  });
}

DoseOutboxSyncEngine _engine({
  required _FakeLocalMedicationStore store,
  required _FakeDoseRemoteDataSource remote,
  required _FakeConnectivityMonitor network,
  SyncDelay delay = _noDelay,
  int batchSize = 10,
  _FakeCheckpointSource? checkpoints,
  PeriodicTimerFactory? periodicTimer,
}) {
  return DoseOutboxSyncEngine(
    localStore: store,
    remoteDataSource: remote,
    connectivityMonitor: network,
    batchSize: batchSize,
    delay: delay,
    clock: () => DateTime.utc(2026, 9, 30),
    checkpointSource: checkpoints,
    periodicTimer: periodicTimer ?? _FakeTimers().create,
  );
}

class _FakeCheckpointSource implements DoseSyncCheckpointSource {
  _FakeCheckpointSource({this.failures = 0});

  int failures;
  int calls = 0;

  @override
  Future<void> recordCheckpoint() async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const ApiException('offline', isTransient: true);
    }
  }
}

class _FakeTimers {
  final intervals = <Duration>[];
  final _callbacks = <void Function(Timer)>[];
  final _timers = <_FakeTimer>[];

  bool get cancelled => _timers.every((timer) => !timer.isActive);

  Timer create(Duration interval, void Function(Timer) callback) {
    intervals.add(interval);
    _callbacks.add(callback);
    final timer = _FakeTimer();
    _timers.add(timer);
    return timer;
  }

  void fire() {
    for (var i = 0; i < _callbacks.length; i++) {
      _callbacks[i](_timers[i]);
    }
  }
}

class _FakeTimer implements Timer {
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
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
    this.results,
  });

  int failuresBeforeSuccess;
  final Object failure;
  final List<DoseUploadResult>? results;
  final uploadedClientUuids = <String>[];

  @override
  Future<List<DoseUploadResult>> uploadDoses(
      List<LocalDoseLog> doseLogs) async {
    uploadedClientUuids.addAll(doseLogs.map((doseLog) => doseLog.clientUuid));

    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw failure;
    }

    final configuredResults = results;
    if (configuredResults != null) {
      return configuredResults;
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
  final errorMessages = <String, String>{};

  bool containsClientUuid(String clientUuid) {
    return _doseLogs.containsKey(clientUuid);
  }

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
    errorMessages[clientUuid] = errorMessage;
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
    String? patientId,
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
  Future<bool> hasDoseLog({
    required int medicationScheduleId,
    required DateTime scheduledAt,
  }) async =>
      false;

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
  Future<void> upsertDoseLog(LocalDoseLog doseLog) async {
    final existing = _doseLogs.values.where(
      (current) =>
          current.medicationScheduleId == doseLog.medicationScheduleId &&
          current.scheduledAt.toUtc() == doseLog.scheduledAt.toUtc(),
    );
    if (existing.isEmpty) {
      _doseLogs[doseLog.clientUuid] = doseLog;
      return;
    }

    final existingDoseLog = existing.first;
    _doseLogs[existingDoseLog.clientUuid] = LocalDoseLog(
      id: doseLog.id,
      clientUuid: existingDoseLog.clientUuid,
      medicationScheduleId: doseLog.medicationScheduleId,
      scheduledAt: doseLog.scheduledAt,
      takenAt: doseLog.takenAt,
      status: doseLog.status,
      syncState: doseLog.syncState,
      syncedAt: doseLog.syncedAt,
      lastError: doseLog.lastError,
      localUpdatedAt: doseLog.localUpdatedAt,
    );
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
