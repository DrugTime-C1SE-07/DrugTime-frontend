import 'dart:async';
import 'dart:io';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../contracts/dose_outbox.dart';
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
    this.status = DoseUploadResultStatus.synced,
    this.serverId,
    this.syncedAt,
    this.errorCode,
    this.errorMessage,
  });

  final String clientUuid;
  final DoseUploadResultStatus status;
  final int? serverId;
  final DateTime? syncedAt;
  final String? errorCode;
  final String? errorMessage;

  bool get isSynced => status == DoseUploadResultStatus.synced;
  bool get isFailed => status == DoseUploadResultStatus.failed;
}

enum DoseUploadResultStatus {
  synced,
  failed,
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
          .whereType<DoseUploadResult>()
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
            .whereType<DoseUploadResult>()
            .toList(growable: false);
      }

      if (response.containsKey('client_uuid')) {
        final result = _resultFromMap(response);
        return result == null ? const [] : [result];
      }
    }

    return const [];
  }

  DoseUploadResult? _resultFromMap(Map<String, Object?> map) {
    final clientUuid = map['client_uuid'];
    if (clientUuid is! String || clientUuid.isEmpty) {
      return null;
    }

    final result = map['result'] as String?;
    if (result == 'failed') {
      final error = map['error'];
      final errorMap = error is Map
          ? Map<String, Object?>.from(error)
          : const <String, Object?>{};
      final code = errorMap['code'] as String?;
      final detail = errorMap['detail'] as String?;
      return DoseUploadResult(
        clientUuid: clientUuid,
        status: DoseUploadResultStatus.failed,
        errorCode: code,
        errorMessage: _formatItemError(code: code, detail: detail),
      );
    }

    if (result != null && result != 'synced') {
      return null;
    }

    return DoseUploadResult(
      clientUuid: clientUuid,
      serverId: _tryParseInt(
        map['dose_log_id'] ?? map['id'] ?? map['server_id'],
      ),
      syncedAt: _tryParseDateTime(map['synced_at'] as String?) ??
          _tryParseDateTime(map['created_at'] as String?),
    );
  }

  String _formatItemError({String? code, String? detail}) {
    if (code != null && detail != null && detail.isNotEmpty) {
      return '$code: $detail';
    }
    if (detail != null && detail.isNotEmpty) {
      return detail;
    }
    if (code != null && code.isNotEmpty) {
      return code;
    }
    return 'Dose upload failed';
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
    DoseOutbox? outbox,
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
        _outbox = outbox,
        _maxAttempts = maxAttempts,
        _batchSize = batchSize,
        _backoffSchedule = backoffSchedule,
        _delay = delay,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final LocalMedicationStore _localStore;
  final DoseRemoteDataSource _remoteDataSource;
  final ConnectivityMonitor _connectivityMonitor;
  final DoseOutbox? _outbox;
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
      final pendingLogs = _outbox != null
          ? await _outbox.getPendingLogs()
          : await _localStore.getPendingDoseLogs();
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

  Future<void> _markDoseLogSynced({
    required String clientUuid,
    required int? serverId,
    required DateTime syncedAt,
  }) async {
    if (_outbox != null) {
      await _outbox.markSynced(
        clientUuid: clientUuid,
        serverId: serverId,
        syncedAt: syncedAt,
      );
    } else {
      await _localStore.markDoseLogSynced(
        clientUuid: clientUuid,
        serverId: serverId,
        syncedAt: syncedAt,
      );
    }
  }

  Future<void> _markDoseLogFailed({
    required String clientUuid,
    required String errorMessage,
  }) async {
    if (_outbox != null) {
      await _outbox.markFailed(
        clientUuid: clientUuid,
        errorMessage: errorMessage,
      );
    } else {
      await _localStore.markDoseLogFailed(
        clientUuid: clientUuid,
        errorMessage: errorMessage,
      );
    }
  }

  Future<bool> _uploadBatchWithRetry(List<LocalDoseLog> doseLogs) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final results = await _remoteDataSource.uploadDoses(doseLogs);
        final requestedClientUuids =
            doseLogs.map((doseLog) => doseLog.clientUuid).toSet();
        final resultByClientUuid = {
          for (final result in results)
            if (requestedClientUuids.contains(result.clientUuid))
              result.clientUuid: result,
        };
        var hasMissingResult = false;

        for (final doseLog in doseLogs) {
          final result = resultByClientUuid[doseLog.clientUuid];
          if (result == null) {
            hasMissingResult = true;
            continue;
          }

          if (result.isSynced) {
            await _markDoseLogSynced(
              clientUuid: doseLog.clientUuid,
              serverId: result.serverId ?? doseLog.id,
              syncedAt: result.syncedAt ?? _clock(),
            );
            continue;
          }

          if (result.isFailed) {
            await _markDoseLogFailed(
              clientUuid: doseLog.clientUuid,
              errorMessage: result.errorMessage ?? 'Dose upload failed',
            );
          }
        }
        return !hasMissingResult;
      } on ApiException catch (error) {
        lastError = error;
        if (!error.isTransient) {
          if (_shouldKeepPending(error)) {
            return false;
          }

          for (final doseLog in doseLogs) {
            await _markDoseLogFailed(
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
        await _markDoseLogFailed(
          clientUuid: doseLog.clientUuid,
          errorMessage: lastError.message,
        );
      }
    }
    return false;
  }

  bool _shouldKeepPending(ApiException error) {
    return error.statusCode == HttpStatus.unauthorized ||
        error.statusCode == HttpStatus.forbidden;
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
