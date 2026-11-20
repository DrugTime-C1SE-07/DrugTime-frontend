import '../../../core/api/api_client.dart';

class PendingAccountDeletion {
  const PendingAccountDeletion(this.requestedAt, this.scheduledAt);
  final DateTime requestedAt;
  final DateTime scheduledAt;
  factory PendingAccountDeletion.fromJson(Object? value) {
    final json = value as Map<String, dynamic>;
    return PendingAccountDeletion(
        DateTime.parse(json['requested_at'] as String),
        DateTime.parse(json['scheduled_deletion_at'] as String));
  }
}

class DeletionChallenge {
  const DeletionChallenge(this.id, this.expiresAt);
  final String id;
  final DateTime expiresAt;
}

abstract class AccountDeletionRepository {
  Future<PendingAccountDeletion?> current();
  Future<DeletionChallenge> issue();
  Future<void> verify(String challenge, String otp);
  Future<PendingAccountDeletion> create(String challenge);
  Future<void> cancel();
}

class RemoteAccountDeletionRepository implements AccountDeletionRepository {
  RemoteAccountDeletionRepository(this.api);
  final ApiClient api;
  static const path = '/data-deletion-requests';
  @override
  Future<PendingAccountDeletion?> current() async {
    final value = await api.getJson('$path/current');
    return value == null ? null : PendingAccountDeletion.fromJson(value);
  }

  @override
  Future<DeletionChallenge> issue() async {
    final json = await api.post('$path/otp', expectedStatus: 201)
        as Map<String, dynamic>;
    return DeletionChallenge(json['challenge_id'] as String,
        DateTime.parse(json['expires_at'] as String));
  }

  @override
  Future<void> verify(String challenge, String otp) async {
    await api.postJson('$path/otp/verify',
        body: {'challenge_id': challenge, 'otp': otp}, expectedStatus: 204);
  }

  @override
  Future<PendingAccountDeletion> create(String challenge) async =>
      PendingAccountDeletion.fromJson(await api
          .postJson(path, body: {'challenge_id': challenge}));
  @override
  Future<void> cancel() async {
    await api.post('$path/current/cancel', expectedStatus: 204);
  }
}
