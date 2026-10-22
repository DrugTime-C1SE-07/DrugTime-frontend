import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_alert.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_alert_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_alert_controller.dart';
import 'remote_family_alert_repository_test.dart' show alertJson;

class AlertRepo implements FamilyAlertRepository {
  Future<FamilyAlertPage> Function()? onList;
  Future<FamilyAlert> Function()? onPatch;
  Future<FamilyAlert> Function()? onDetail;
  bool read = false;
  @override
  Future<FamilyAlertPage> list({int offset = 0, int limit = 20}) async =>
      onList != null
          ? onList!()
          : FamilyAlertPage(
              [FamilyAlert.fromJson(alertJson(read: read))], 1, read ? 0 : 1);
  @override
  Future<FamilyAlert> detail(int id) async => onDetail != null
      ? onDetail!()
      : FamilyAlert.fromJson(alertJson(read: read));
  @override
  Future<FamilyAlert> markRead(int id) async {
    if (onPatch != null) return onPatch!();
    read = true;
    return FamilyAlert.fromJson(alertJson(read: true));
  }
}

void main() {
  for (final fails in [false, true]) {
    test('late PATCH from another detail is ignored (failure: $fails)',
        () async {
      final repo = AlertRepo();
      final c = FamilyAlertController(repo)..setSession('A', ready: true);
      await c.open(1);
      final pending = Completer<FamilyAlert>();
      repo.onPatch = () => pending.future;
      final save = c.markRead();
      repo.onDetail = () async => FamilyAlert.fromJson(alertJson(id: 2));
      await c.open(2);
      if (fails) {
        pending.completeError(const FamilyAlertFailure('forbidden'));
      } else {
        pending.complete(FamilyAlert.fromJson(alertJson(read: true)));
      }
      await save;
      expect(c.detail!.id, 2);
      expect(c.error, isNull);
      expect(c.saving, false);
      c.dispose();
    });
  }
  test(
      'PATCH waits for server, failure preserves unread, success GET confirms badge',
      () async {
    final repo = AlertRepo();
    final c = FamilyAlertController(repo)..setSession('A', ready: true);
    await c.load();
    await c.open(1);
    final pending = Completer<FamilyAlert>();
    repo.onPatch = () => pending.future;
    final save = c.markRead();
    expect(c.detail!.isRead, false);
    expect(c.unreadCount, 1);
    pending.completeError(const FamilyAlertFailure('unavailable'));
    await save;
    expect(c.detail!.isRead, false);
    expect(c.error, isNotNull);
    repo.onPatch = null;
    await c.markRead();
    expect(c.detail!.isRead, true);
    expect(c.unreadCount, 0);
    c.dispose();
  });
  test('background/offline/session clear discards late responses and badge',
      () async {
    final repo = AlertRepo();
    final c = FamilyAlertController(repo)..setSession('A', ready: true);
    final pending = Completer<FamilyAlertPage>();
    repo.onList = () => pending.future;
    final load = c.load();
    c.setSession('B', ready: true);
    pending
        .complete(FamilyAlertPage([FamilyAlert.fromJson(alertJson())], 1, 1));
    await load;
    expect(c.items, isEmpty);
    expect(c.unreadCount, isNull);
    repo.onList = null;
    await c.load();
    c.clear();
    expect(c.items, isEmpty);
    expect(c.detail, isNull);
    expect(c.unreadCount, isNull);
    c.dispose();
  });
  test('revoked and badge failure never present previously confirmed count',
      () async {
    final repo = AlertRepo();
    final c = FamilyAlertController(repo)..setSession('A', ready: true);
    await c.load();
    await c.open(1);
    repo.onList = () async => throw const FamilyAlertFailure('unavailable');
    await c.load();
    expect(c.unreadCount, isNull);
    repo.onDetail = () async => throw const FamilyAlertFailure('forbidden');
    await c.open(1);
    expect(c.detail, isNull);
    expect(c.items, isEmpty);
    expect(c.error!.kind, 'forbidden');
    c.dispose();
  });
}
