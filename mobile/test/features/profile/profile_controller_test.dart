import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/profile_failure.dart';
import 'profile_test_helpers.dart';

void main() {
  late FakeProfileRepository repo;
  late ProfileController c;
  final draft = ProfileDraft(
      fullName: 'Tên mới', dateOfBirth: DateTime(1960, 1, 1), gender: 'nu');
  setUp(() {
    repo = FakeProfileRepository();
    c = ProfileController(repo);
  });
  tearDown(() => c.dispose());
  test('load, serialize submit, update and refetch only after ACK', () async {
    await c.load();
    repo.pendingWrite = Completer();
    final first = c.update(draft);
    expect(c.saving, isTrue);
    expect(c.notice, isNull);
    expect(await c.update(draft), isFalse);
    expect(repo.writes, 1);
    repo.pendingWrite!.complete();
    expect(await first, isTrue);
    expect(c.profile!.fullName, 'Tên mới');
    expect(repo.reads, 2);
  });
  test('clear rejects delayed read and resets avatar/catalog', () async {
    repo.pendingRead = Completer();
    final future = c.load();
    c.selectAvatar(AppAssets.profileAvatars.first);
    c.clear();
    repo.pendingRead!.complete(const HealthProfile(fullName: 'Old account'));
    await future;
    expect(c.profile, isNull);
    expect(c.avatar, isNull);
    expect(c.catalogItems, isEmpty);
  });
  test('clear rejects delayed write and does not refetch old account',
      () async {
    await c.load();
    repo.pendingWrite = Completer();
    final future = c.update(draft);
    c.clear();
    repo.pendingWrite!.complete();
    expect(await future, isFalse);
    expect(c.profile, isNull);
    expect(repo.reads, 1);
  });
  test('403 removes profile and blocks writes; consent can reload', () async {
    await c.load();
    repo.fetchFailure = const ProfileFailure(ProfileFailureKind.consent);
    await c.load();
    expect(c.denied, isTrue);
    expect(c.profile, isNull);
    expect(await c.update(draft), isFalse);
    repo.fetchFailure = null;
    await c.load();
    expect(c.denied, isFalse);
    expect(c.profile, isNotNull);
  });
  test('revoke clears data and invalidates pending response', () async {
    await c.load();
    repo.pendingRead = Completer();
    final pending = c.load();
    c.revoke();
    repo.pendingRead!.complete(repo.value);
    await pending;
    expect(c.profile, isNull);
    expect(c.denied, isTrue);
  });
  test('catalog pages keep selected profile conditions', () async {
    await c.load();
    await c.addCondition(45);
    await c.loadCatalog();
    await c.loadCatalog();
    expect(repo.offsets, [0, 1]);
    expect(c.hasMore, isFalse);
    expect(c.profile!.conditions.single.conditionId, 45);
  });
  test('network loss after POST reconciles without duplicate write', () async {
    await c.load();
    repo.writeFailure = const ProfileFailure(ProfileFailureKind.network);
    expect(await c.addCondition(3), isTrue);
    expect(repo.writes, 1);
    expect(c.profile!.conditions.length, 1);
  });
  test('duplicate remains an explicit error even after refresh', () async {
    await c.load();
    repo.writeFailure = const ProfileFailure(ProfileFailureKind.duplicate);
    expect(await c.addCondition(3), isFalse);
    expect(c.error!.kind, ProfileFailureKind.duplicate);
  });
  test('write ACK followed by failed refresh does not retry write', () async {
    await c.load();
    repo.failFetchAfterWrite = true;
    expect(await c.update(draft), isTrue);
    expect(repo.writes, 1);
    expect(c.notice, contains('Đã lưu.'));
  });
  test('PATCH omission and delete 404 reconcile by link ID', () async {
    await c.load();
    await c.addCondition(3);
    await c.updateCondition(99, {'stage': null});
    expect(repo.lastPatch, {'stage': null});
    expect(repo.lastLink, 99);
    repo.writeFailure = const ProfileFailure(ProfileFailureKind.missing);
    expect(await c.deleteCondition(99), isTrue);
    expect(c.profile!.conditions, isEmpty);
  });
  test('network error does not discard profile and no write success', () async {
    await c.load();
    repo.writeFailure = const ProfileFailure(ProfileFailureKind.network);
    expect(await c.update(draft), isFalse);
    expect(c.profile, isNotNull);
    expect(c.notice, isNull);
  });
  test('unsupported runtime has no sample fallback', () async {
    final other = ProfileController(null);
    await other.load();
    expect(other.profile, isNull);
    expect(other.error!.kind, ProfileFailureKind.unsupported);
    other.dispose();
  });
  test('dispose prevents pending callbacks from notifying', () async {
    final other = ProfileController(repo);
    repo.pendingRead = Completer();
    final pending = other.load();
    other.dispose();
    repo.pendingRead!.complete(repo.value);
    await pending;
  });
}
