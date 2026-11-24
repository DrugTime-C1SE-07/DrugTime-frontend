import 'dart:async';

import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/core/sync/sync_engine.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/account_deletion_repository.dart';
import 'package:drugtime_mobile/features/consent/data/account_deletion_status_store.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/account_deletion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivity implements ConnectivityMonitor {
  final _controller = StreamController<bool>.broadcast();
  bool _online = false;

  void emit(bool online) {
    _online = online;
    _controller.add(online);
  }

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  @override
  Future<bool> get isOnline async => _online;

  @override
  Future<void> dispose() => _controller.close();
}

class _FakeDeletionRepo implements AccountDeletionRepository {
  PendingAccountDeletion? pending;
  Object? lookupError;
  int currentCalls = 0;
  int cancelCalls = 0;
  Future<void> Function()? onCurrentError401;

  @override
  Future<PendingAccountDeletion?> current() async {
    currentCalls++;
    if (lookupError != null) {
      final err = lookupError!;
      if (err is ApiException && err.statusCode == 401) {
        await onCurrentError401?.call();
      }
      throw err;
    }
    return pending;
  }

  @override
  Future<DeletionChallenge> issue() => throw UnimplementedError();

  @override
  Future<void> verify(String challenge, String otp) =>
      throw UnimplementedError();

  @override
  Future<PendingAccountDeletion> create(String challenge) =>
      throw UnimplementedError();

  @override
  Future<void> cancel() async {
    cancelCalls++;
    pending = null;
  }
}

Future<AuthController> _pumpGate(
  WidgetTester tester, {
  required _FakeDeletionRepo repo,
  required AccountDeletionStatusStore store,
  _FakeConnectivity? connectivity,
  ValueNotifier<int>? recheckNotifier,
  String userId = 'user-1',
  String token = 'token-1',
}) async {
  final auth = AuthController(InMemoryAuthRepository(
    simulatedDelay: Duration.zero,
    initialSession: AuthSession(
      userId: userId,
      accessToken: token,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      profileComplete: true,
    ),
  ));
  await auth.initSession();

  await tester.pumpWidget(AuthScope(
    controller: auth,
    child: AccountDeletionScope(
      repository: repo,
      statusStore: store,
      connectivity: connectivity,
      recheckNotifier: recheckNotifier,
      clock: () => DateTime.utc(2026, 11, 22, 12, 0),
      child: const MaterialApp(
        home: AccountDeletionGate(
          child: Scaffold(body: Text('APP_HOME_CONTENT')),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return auth;
}

void main() {
  final samplePending = PendingAccountDeletion(
    DateTime.utc(2026, 11, 20, 8, 0),
    DateTime.utc(2026, 12, 20, 8, 0),
  );

  testWidgets(
      'AC1: cache pending == null + mất mạng → mở app bình thường không chặn',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    await store.write(
      'user-1',
      pending: null,
      verifiedAt: DateTime.utc(2026, 11, 22, 10, 0),
    );
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('Request timed out', isTransient: true);

    await _pumpGate(tester, repo: repo, store: store);

    expect(find.text('APP_HOME_CONTENT'), findsOneWidget);
    final offstage = tester.widget<Offstage>(find.ancestor(
      of: find.text('APP_HOME_CONTENT'),
      matching: find.byType(Offstage),
    ).first);
    expect(offstage.offstage, isFalse);
    expect(find.byType(AccountDeletionScreen), findsNothing);
  });

  testWidgets(
      'AC2: cache pending != null + mất mạng → chặn bằng màn chờ xóa, không tự hủy',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    await store.write(
      'user-1',
      pending: samplePending,
      verifiedAt: DateTime.utc(2026, 11, 22, 10, 0),
    );
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('No connection', isTransient: true);

    await _pumpGate(tester, repo: repo, store: store);

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    final screen = tester.widget<AccountDeletionScreen>(
      find.byType(AccountDeletionScreen),
    );
    expect(screen.pending, isNotNull);
    expect(repo.cancelCalls, 0);
  });

  testWidgets(
      'AC3: phiên mới chưa có cache + mất mạng → chặn và hiện nút Thử lại',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('No connection', isTransient: true);

    await _pumpGate(tester, repo: repo, store: store);

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    final screen = tester.widget<AccountDeletionScreen>(
      find.byType(AccountDeletionScreen),
    );
    expect(screen.statusError, isNotNull);
    expect(screen.onRetry, isNotNull);
  });

  testWidgets(
      'AC4: vào app offline rồi có mạng trở lại phát hiện cho_xoa → lập tức bật overlay',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    await store.write(
      'user-1',
      pending: null,
      verifiedAt: DateTime.utc(2026, 11, 22, 10, 0),
    );
    final connectivity = _FakeConnectivity();
    addTearDown(connectivity.dispose);
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('offline', isTransient: true);

    await _pumpGate(
      tester,
      repo: repo,
      store: store,
      connectivity: connectivity,
    );
    expect(find.byType(AccountDeletionScreen), findsNothing);

    // Thiết bị khác đã tạo yêu cầu xóa; nay thiết bị này có mạng trở lại.
    repo.lookupError = null;
    repo.pending = samplePending;
    connectivity.emit(true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    final cached = await store.read('user-1');
    expect(cached?.pending, isNotNull);
    expect(repo.cancelCalls, 0);
  });

  testWidgets(
      'AC4 (resumed): vào app offline rồi app resumed có mạng phát hiện cho_xoa → bật overlay',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    await store.write(
      'user-1',
      pending: null,
      verifiedAt: DateTime.utc(2026, 11, 22, 10, 0),
    );
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('offline', isTransient: true);

    await _pumpGate(tester, repo: repo, store: store);
    expect(find.byType(AccountDeletionScreen), findsNothing);

    repo.lookupError = null;
    repo.pending = samplePending;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
  });

  testWidgets(
      'AC5: kiểm tra ngầm nhận 401 → xóa cache trạng thái xóa và chạy handleUnauthorized',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    await store.write(
      'user-1',
      pending: null,
      verifiedAt: DateTime.utc(2026, 11, 22, 10, 0),
    );
    final connectivity = _FakeConnectivity();
    addTearDown(connectivity.dispose);
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('offline', isTransient: true);

    final auth = await _pumpGate(
      tester,
      repo: repo,
      store: store,
      connectivity: connectivity,
    );
    expect(auth.isAuthenticated, isTrue);

    repo.lookupError = const ApiException('Unauthorized', statusCode: 401);
    repo.onCurrentError401 = auth.handleUnauthorized;
    connectivity.emit(true);
    await tester.pump();
    await tester.pump();

    expect(auth.isAuthenticated, isFalse);
    expect(await store.read('user-1'), isNull);
  });

  testWidgets(
      'AC6 (mobile): nhận trigger 403 account_pending_deletion khi đang mở app → tải lại và bật overlay',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    final recheck = ValueNotifier<int>(0);
    addTearDown(recheck.dispose);
    final repo = _FakeDeletionRepo()..pending = null;

    await _pumpGate(
      tester,
      repo: repo,
      store: store,
      recheckNotifier: recheck,
    );
    expect(find.byType(AccountDeletionScreen), findsNothing);
    expect((await store.read('user-1'))?.pending, isNull);

    // Server chuyển sang cho_xoa và một API khác trả 403 account_pending_deletion.
    repo.pending = samplePending;
    recheck.value++;
    await tester.pump();
    await tester.pump();

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect((await store.read('user-1'))?.pending, isNotNull);
  });

  testWidgets(
      'AC8 (mobile): bấm hủy yêu cầu xóa thành công → cập nhật cache null và đóng overlay',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    final repo = _FakeDeletionRepo()..pending = samplePending;

    await _pumpGate(tester, repo: repo, store: store);
    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect((await store.read('user-1'))?.pending, isNotNull);

    await tester.tap(find.text('Đăng nhập lại'));
    await tester.pump();
    await tester.pump();

    expect(repo.cancelCalls, 1);
    expect(find.byType(AccountDeletionScreen), findsNothing);
    final cached = await store.read('user-1');
    expect(cached, isNotNull);
    expect(cached!.pending, isNull);
  });

  testWidgets(
      'TC-DELOFF-04: cache pending == null + lỗi HTTP 4xx không tạm thời → vẫn chặn và hiện nút Thử lại',
      (tester) async {
    final store = InMemoryAccountDeletionStatusStore();
    await store.write(
      'user-1',
      pending: null,
      verifiedAt: DateTime.utc(2026, 11, 22, 10, 0),
    );
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException(
        'Bad Request',
        statusCode: 400,
        isTransient: false,
      );

    await _pumpGate(tester, repo: repo, store: store);

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    final screen = tester.widget<AccountDeletionScreen>(
      find.byType(AccountDeletionScreen),
    );
    expect(screen.statusError, isNotNull);
    expect(screen.onRetry, isNotNull);
  });

  testWidgets(
      'lỗi SecureStorage khi read trong catch offline → không kẹt spinner, fail-closed với nút Thử lại',
      (tester) async {
    final store = _ThrowingStatusStore();
    final repo = _FakeDeletionRepo()
      ..lookupError = const ApiException('No connection', isTransient: true);

    await _pumpGate(tester, repo: repo, store: store);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    final screen = tester.widget<AccountDeletionScreen>(
      find.byType(AccountDeletionScreen),
    );
    expect(screen.statusError, isNotNull);
    expect(screen.onRetry, isNotNull);
  });

  testWidgets(
      'lỗi SecureStorage khi write sau khi server xác nhận bình thường → vẫn mở app không chặn',
      (tester) async {
    final store = _ThrowingStatusStore();
    final repo = _FakeDeletionRepo()..pending = null;

    await _pumpGate(tester, repo: repo, store: store);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AccountDeletionScreen), findsNothing);
    final offstage = tester.widget<Offstage>(find.ancestor(
      of: find.text('APP_HOME_CONTENT'),
      matching: find.byType(Offstage),
    ).first);
    expect(offstage.offstage, isFalse);
  });
}

class _ThrowingStatusStore implements AccountDeletionStatusStore {
  @override
  Future<CachedDeletionStatus?> read(String userId) async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }

  @override
  Future<void> write(
    String userId, {
    required PendingAccountDeletion? pending,
    required DateTime verifiedAt,
  }) async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }

  @override
  Future<void> clear(String userId) async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }

  @override
  Future<void> clearAll() async {
    throw PlatformException(code: 'keystore_error', message: 'Keystore locked');
  }
}
