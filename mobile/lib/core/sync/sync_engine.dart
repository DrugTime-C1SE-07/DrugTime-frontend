import 'dart:async';
import 'dart:io';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../storage/local_db/local_medication_store.dart';
import '../storage/local_db/local_models.dart';

abstract class ConnectivityMonitor {
  Stream<bool> get onlineChanges;
  Future<bool> get isOnline;
  Future<void> dispose();
}

typedef InternetLookup = Future<List<InternetAddress>> Function(String host);

class PollingConnectivityMonitor implements ConnectivityMonitor {
  PollingConnectivityMonitor({
    Duration interval = const Duration(seconds: 5),
    String lookupHost = 'example.com',
    InternetLookup lookup = InternetAddress.lookup,
  })  : _interval = interval,
        _lookupHost = lookupHost,
        _lookup = lookup;

  final Duration _interval;
  final String _lookupHost;
  final InternetLookup _lookup;
  final _controller = StreamController<bool>.broadcast();

  Timer? _timer;
  bool? _lastKnownOnline;

  @override
  Stream<bool> get onlineChanges {
    _timer ??= Timer.periodic(_interval, (_) => unawaited(_emitIfChanged()));
    unawaited(_emitIfChanged());
    return _controller.stream;
  }

  @override
  Future<bool> get isOnline => _checkOnline();

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _controller.close();
  }

  Future<void> _emitIfChanged() async {
    final online = await _checkOnline();
    if (_lastKnownOnline == online) {
      return;
    }

    _lastKnownOnline = online;
    if (!_controller.isClosed) {
      _controller.add(online);
    }
  }

  Future<bool> _checkOnline() async {
    try {
      final addresses = await _lookup(_lookupHost);
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }
}

abstract class DoseRemoteDataSource {
  Future<List<DoseUploadResult>> uploadDoses(List<LocalDoseLog> doseLogs);
}

class DoseUploadResult {
  const DoseUploadResult({
    required this.clientUuid,
    this.serverId,
    this.syncedAt,
  });

  final String clientUuid;
  final int? serverId;
  final DateTime? syncedAt;
}

class DoseApiRemoteDataSource implements DoseRemoteDataSource {
  DoseApiRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<DoseUploadResult>> uploadDoses(
      List<LocalDoseLog> doseLogs) async {
    final response = await _apiClient.postJson(
      '/doses/batch',
      body: doseLogs.map(_toBackendPayload).toList(growable: false),
    );

    return _parseUploadResults(response, doseLogs);
  }

  Map<String, Object?> _toBackendPayload(LocalDoseLog doseLog) {
    final takenAt = doseLog.takenAt;
    if (takenAt == null) {
      throw const ApiException(
        'taken_at is required by /doses/batch',
        isTransient: false,
      );
    }

    return {
      'client_uuid': doseLog.clientUuid,
      'schedule_id': doseLog.medicationScheduleId,
      'scheduled_at': doseLog.scheduledAt.toUtc().toIso8601String(),
      'taken_at': takenAt.toUtc().toIso8601String(),
    };
  }

  List<DoseUploadResult> _parseUploadResults(
    Object? response,
    List<LocalDoseLog> doseLogs,
  ) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .map(_resultFromMap)
          .toList(growable: false);
    }

    if (response is Map<String, Object?>) {
      final items =
          response['items'] ?? response['results'] ?? response['data'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, Object?>.from(item))
            .map(_resultFromMap)
            .toList(growable: false);
      }

      if (response.containsKey('client_uuid')) {
        return [_resultFromMap(response)];
      }
    }

    return doseLogs
        .map((doseLog) => DoseUploadResult(clientUuid: doseLog.clientUuid))
        .toList(growable: false);
  }

  DoseUploadResult _resultFromMap(Map<String, Object?> map) {
    return DoseUploadResult(
      clientUuid: map['client_uuid'] as String,
      serverId: _tryParseInt(map['id'] ?? map['server_id']),
      syncedAt: _tryParseDateTime(map['synced_at'] as String?) ??
          _tryParseDateTime(map['created_at'] as String?),
    );
  }

  int? _tryParseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  DateTime? _tryParseDateTime(String? value) {
    return value == null ? null : DateTime.tryParse(value);
  }
}

typedef SyncDelay = Future<void> Function(Duration duration);
typedef Clock = DateTime Function();

class DoseOutboxSyncEngine {
  DoseOutboxSyncEngine({
    required LocalMedicationStore localStore,
    required DoseRemoteDataSource remoteDataSource,
    required ConnectivityMonitor connectivityMonitor,
    int maxAttempts = 3,
    int batchSize = 10,
    List<Duration> backoffSchedule = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 7),
    ],
    SyncDelay delay = Future<void>.delayed,
    Clock? clock,
  })  : _localStore = localStore,
        _remoteDataSource = remoteDataSource,
        _connectivityMonitor = connectivityMonitor,
        _maxAttempts = maxAttempts,
        _batchSize = batchSize,
        _backoffSchedule = backoffSchedule,
        _delay = delay,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final LocalMedicationStore _localStore;
  final DoseRemoteDataSource _remoteDataSource;
  final ConnectivityMonitor _connectivityMonitor;
  final int _maxAttempts;
  final int _batchSize;
  final List<Duration> _backoffSchedule;
  final SyncDelay _delay;
  final Clock _clock;

  StreamSubscription<bool>? _connectivitySubscription;
  Future<void>? _activeSync;
  bool _disposed = false;

  Future<void> start() async {
    _connectivitySubscription ??=
        _connectivityMonitor.onlineChanges.listen((isOnline) {
      if (isOnline) {
        unawaited(syncPendingDoseLogs());
      }
    });

    if (await _connectivityMonitor.isOnline) {
      await syncPendingDoseLogs();
    }
  }

  Future<void> syncPendingDoseLogs() {
    final currentSync = _activeSync;
    if (currentSync != null) {
      return currentSync;
    }

    final sync = _syncPendingDoseLogs();
    _activeSync = sync.whenComplete(() => _activeSync = null);
    return _activeSync!;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _connectivityMonitor.dispose();
  }

  Future<void> _syncPendingDoseLogs() async {
    if (_disposed || !await _connectivityMonitor.isOnline) {
      return;
    }

    while (!_disposed && await _connectivityMonitor.isOnline) {
      final pendingLogs = await _localStore.getPendingDoseLogs();
      if (pendingLogs.isEmpty) {
        return;
      }

      final batch = pendingLogs.take(_batchSize).toList(growable: false);
      final uploaded = await _uploadBatchWithRetry(batch);

      if (!uploaded) {
        return;
      }
    }
  }

  Future<bool> _uploadBatchWithRetry(List<LocalDoseLog> doseLogs) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final results = await _remoteDataSource.uploadDoses(doseLogs);
        final resultByClientUuid = {
          for (final result in results) result.clientUuid: result,
        };

        for (final doseLog in doseLogs) {
          final result = resultByClientUuid[doseLog.clientUuid];
          await _localStore.markDoseLogSynced(
            clientUuid: doseLog.clientUuid,
            serverId: result?.serverId ?? doseLog.id,
            syncedAt: result?.syncedAt ?? _clock(),
          );
        }
        return true;
      } on ApiException catch (error) {
        lastError = error;
        if (!error.isTransient) {
          for (final doseLog in doseLogs) {
            await _localStore.markDoseLogFailed(
              clientUuid: doseLog.clientUuid,
              errorMessage: error.message,
            );
          }
          return false;
        }
      } catch (error) {
        lastError = error;
      }

      if (attempt < _maxAttempts) {
        await _delay(_backoffForAttempt(attempt));
      }
    }

    // Transient failures remain pending so a later connectivity event or app
    // launch can retry without user intervention.
    if (lastError is ApiException && !lastError.isTransient) {
      for (final doseLog in doseLogs) {
        await _localStore.markDoseLogFailed(
          clientUuid: doseLog.clientUuid,
          errorMessage: lastError.message,
        );
      }
    }
    return false;
  }

  Duration _backoffForAttempt(int attempt) {
    if (_backoffSchedule.isEmpty) {
      return Duration.zero;
    }

    final index = attempt - 1;
    if (index < _backoffSchedule.length) {
      return _backoffSchedule[index];
    }

    return _backoffSchedule.last;
  }
}
