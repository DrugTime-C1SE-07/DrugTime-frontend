import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_medication_store.dart';
import 'package:drugtime_mobile/core/storage/local_db/local_models.dart';
import 'package:drugtime_mobile/core/sync/background_sync.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_session_store.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _now = DateTime.utc(2026, 10, 5, 3);

AuthSession _session({DateTime? expiresAt}) => AuthSession(
      userId: 'patient-1',
      accessToken: 'token-1',
      expiresAt: expiresAt ?? _now.add(const Duration(days: 1)),
    );

void main() {
  test('no session → no request', () async {
    var built = 0;

    final drained = await runBackgroundSync(
      sessionStore: MemoryAuthSessionStore(),
      buildClient: (_) {
        built++;
        throw StateError('must not build a client');
      },
      now: () => _now,
    );

    expect(drained, isFalse);
    expect(built, 0);
  });

  test('expired session → no request', () async {
    var built = 0;

    final drained = await runBackgroundSync(
      sessionStore: MemoryAuthSessionStore(
          _session(expiresAt: _now.subtract(const Duration(seconds: 1)))),
      buildClient: (_) {
        built++;
        throw StateError('must not build a client');
      },
      now: () => _now,
    );

    expect(drained, isFalse);
    expect(built, 0);
  });

  test('sync then checkpoint with the stored session token', () async {
    final harness = _Harness(status: 200);

    final drained = await runBackgroundSync(
      sessionStore: MemoryAuthSessionStore(_session()),
      buildClient: harness.client,
      buildEngine: harness.engine,
      now: () => _now,
    );

    expect(drained, isTrue);
    expect(harness.requests.map((r) => r.url.path),
        ['/doses/batch', '/doses/sync-checkpoints']);
    expect(
        harness.requests
            .every((r) => r.headers['Authorization'] == 'Bearer token-1'),
        isTrue);
    expect(harness.disposed, isTrue);
  });

  test('401 stops without checkpoint and keeps the session', () async {
    final harness = _Harness(status: 401);
    final store = MemoryAuthSessionStore(_session());

    final drained = await runBackgroundSync(
      sessionStore: store,
      buildClient: harness.client,
      buildEngine: harness.engine,
      now: () => _now,
    );

    expect(drained, isFalse);
    expect(harness.requests.map((r) => r.url.path), ['/doses/batch']);
    expect(store.session, isNotNull);
    expect(harness.disposed, isTrue);
  });
}

class _Harness {
  _Harness({required this.status});

  final int status;
  final requests = <http.Request>[];
  bool disposed = false;

  ApiClient client(String token) => ApiClient(
        baseUrl: Uri.parse('https://api.example.test/'),
        authTokenProvider: () async => token,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (status != 200) return http.Response('{"detail":"x"}', status);
          if (request.url.path == '/doses/batch') {
            return http.Response(
              '{"items":[{"client_uuid":"dose-1","result":"synced",'
              '"dose_log_id":1,"synced_at":"2026-10-05T03:00:00Z"}],'
              '"summary":{"total":1,"synced":1,"failed":0}}',
              200,
            );
          }
          return http.Response('', 204);
        }),
      );

  DoseOutboxSyncEngine engine(ApiClient client) => DoseOutboxSyncEngine(
        localStore: _Store(),
        remoteDataSource: DoseApiRemoteDataSource(client),
        connectivityMonitor: _Network(onDispose: () => disposed = true),
        checkpointSource: ApiDoseSyncCheckpointSource(client),
        delay: (_) async {},
      );
}

class _Network implements ConnectivityMonitor {
  _Network({required this.onDispose});

  final void Function() onDispose;

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();

  @override
  Future<void> dispose() async => onDispose();
}

class _Store implements LocalMedicationStore {
  final _pending = <LocalDoseLog>[
    LocalDoseLog(
      clientUuid: 'dose-1',
      medicationScheduleId: 12,
      scheduledAt: DateTime.utc(2026, 10, 5, 1),
      takenAt: DateTime.utc(2026, 10, 5, 1, 5),
      status: DoseLogStatus.taken,
      syncState: DoseLogSyncState.pendingUpload,
      localUpdatedAt: DateTime.utc(2026, 10, 5, 1, 5),
    ),
  ];

  @override
  Future<List<LocalDoseLog>> getPendingDoseLogs() async => List.of(_pending);

  @override
  Future<void> markDoseLogSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async =>
      _pending.removeWhere((log) => log.clientUuid == clientUuid);

  @override
  Future<void> markDoseLogFailed({
    required String clientUuid,
    required String errorMessage,
  }) async =>
      _pending.removeWhere((log) => log.clientUuid == clientUuid);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
