import 'dart:async';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import 'device_token_store.dart';
import 'family_push_service.dart';

/// The queue owns immutable bearer sessions; stale callbacks never consult current auth.
class DeviceTokenCoordinator {
  DeviceTokenCoordinator(
      {required this.messaging,
      required this.store,
      required this.clientForSession,
      required this.clearNotifications,
      required this.clearHealth});
  final FamilyMessaging messaging;
  final DeviceTokenStore store;
  final ApiClient Function(AuthSession) clientForSession;
  final Future<void> Function() clearNotifications;
  final void Function() clearHealth;
  AuthSession? _session;
  Future<void> _tail = Future.value();
  StreamSubscription<String>? _refresh;
  int _epoch = 0;
  bool _stopping = false;
  bool get blocksRegistration => _stopping && _session != null;
  Object? lastError;
  // Tuần tự hóa PUT/refresh/logout; giữ lỗi từng bước mà không khóa cả hàng đợi.
  Future<void> _queue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object e, StackTrace s) {
      lastError = e;
    });
    return next;
  }

  Future<void> activate(AuthSession session) {
    // Epoch loại callback phiên cũ; mỗi tác vụ HTTP giữ bearer của phiên đã chụp.
    final generation = ++_epoch;
    _session = session;
    _stopping = false;
    _refresh ??= messaging.tokenRefresh.listen((token) {
      final captured = _session, epoch = _epoch;
      if (_stopping || captured == null) return;
      unawaited(_queue(() async {
        if (_stopping || epoch != _epoch) return;
        // SDK events can arrive after an installation was rotated for another account.
        final current = await messaging.getToken();
        if (current != token || _stopping || epoch != _epoch) return;
        await _register(captured, epoch, token);
      }).catchError((Object e) {
        lastError = e;
      }));
    });
    return _queue(() async {
      final old = await store.read();
      // Khôi phục cleanup dang dở sau restart trước khi đăng ký token cho phiên mới.
      if (old != null && (old.cleanup || old.owner != session.userId)) {
        if (old.owner == session.userId && !session.isExpired) {
          try {
            await _removeServer(session, old);
          } on ApiException catch (e) {
            if (e.statusCode != 401) rethrow;
          }
        }
        await _rotate(old);
      }
      if (_stopping || generation != _epoch) return;
      await messaging.setAutoInit(true);
      final token = await messaging.getToken();
      if (token != null) await _register(session, generation, token);
    });
  }

  Future<void> _register(AuthSession session, int epoch, String token) async {
    if (_stopping || epoch != _epoch || session.isExpired) return;
    final previous = await store.read();
    if (_stopping || epoch != _epoch) return;
    // Persist cleanup intent before PUT: a crash may happen after the server commits.
    await store.write(DeviceTokenRecord(session.userId, token,
        cleanup: true,
        previousToken: previous?.token == token
            ? previous?.previousToken
            : previous?.token));
    try {
      await clientForSession(session).putJson('/me/device-tokens',
          body: {
            'fcm_token': token,
            'platform': 'android',
            if (previous != null &&
                previous.owner == session.userId &&
                previous.token != token)
              'previous_fcm_token': previous.token,
          },
          expectedStatus: 204);
      await store.write(DeviceTokenRecord(session.userId, token));
      lastError = null;
    } on ApiException catch (e) {
      lastError = e;
      if (e.statusCode == 409 || e.statusCode == 401) {
        final pending = await store.read();
        if (pending != null) await _rotate(pending);
        // A later retry obtains a fresh installation token; never claim another owner's token.
      }
      rethrow;
    }
  }

  Future<void> _rotate(DeviceTokenRecord record) async {
    await store.write(DeviceTokenRecord(record.owner, record.token,
        cleanup: true, previousToken: record.previousToken));
    await messaging.setAutoInit(false);
    await messaging.deleteToken();
    await clearNotifications();
    await store.clear();
  }

  // Chặn refresh ngay, chờ PUT đang chạy rồi gỡ server bằng bearer phiên đăng xuất.
  Future<void> logout(AuthSession session) {
    _stopping = true;
    _epoch++;
    clearHealth();
    return _queue(() async {
      final record = await store.read();
      if (record != null) {
        await store.write(DeviceTokenRecord(record.owner, record.token,
            cleanup: true, previousToken: record.previousToken));
        if (record.owner == session.userId) {
          await _removeServer(session, record);
        }
        await _rotate(record);
      } else {
        await messaging.setAutoInit(false);
        await messaging.deleteToken();
        await clearNotifications();
      }
      _session = null;
    });
  }

  Future<void> _removeServer(
      AuthSession session, DeviceTokenRecord record) async {
    // PUT bị ngắt có thể đã commit; dọn cả token mới lẫn token cũ đã ghi trước request.
    for (final token in {
      record.token,
      if (record.previousToken != null) record.previousToken!
    }) {
      await clientForSession(session).deleteJson('/me/device-tokens',
          body: {'fcm_token': token}, expectedStatus: 204);
    }
  }

  Future<void> expire() {
    _stopping = true;
    _epoch++;
    _session = null;
    clearHealth();
    // No HTTP DELETE here: a 401 handler must never recurse or wait on its own PUT.
    return _queue(() async {
      final record = await store.read();
      if (record != null) {
        await _rotate(record);
      } else {
        await messaging.setAutoInit(false);
        await messaging.deleteToken();
        await clearNotifications();
      }
    });
  }

  Future<void> dispose() async {
    _stopping = true;
    _epoch++;
    await _refresh?.cancel();
    await _tail;
  }
}
