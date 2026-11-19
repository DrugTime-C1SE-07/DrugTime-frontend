import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/patient_dose_reminders/data/patient_dose_reminder_repository.dart';
import 'package:drugtime_mobile/features/patient_dose_reminders/presentation/patient_dose_reminder_controller.dart';

class ReminderRepo extends PatientDoseReminderRepository {
  ReminderRepo() : super(ApiClient(baseUrl: Uri.parse('https://test.invalid')));
  final sent = <String>[];
  Completer<ReminderReceipt>? pending;
  bool timeout = false;
  int reads = 0;
  Duration? cooldown;
  @override
  Future<ReminderReceipt?> status(String patientId, OccurrenceKey key) async {
    reads++;
    return null;
  }

  @override
  Future<ReminderReceipt> send(
      String patientId, OccurrenceKey key, String uuid) async {
    sent.add(uuid);
    if (timeout) throw const ApiException('timeout', isTransient: true);
    if (cooldown != null) {
      throw ApiException('cooldown', statusCode: 429, retryAfter: cooldown);
    }
    return pending?.future ??
        ReminderReceipt(
            1,
            patientId,
            key.$1,
            key.$2,
            DateTime.utc(2026, 11, 19, 2),
            DateTime.utc(2026, 11, 19, 2, 10),
            'accepted');
  }
}

void main() {
  final key = (2, DateTime.utc(2026, 11, 19, 1));
  final now = DateTime.utc(2026, 11, 19, 2);
  test('timeout retries exact UUID and double tap creates only one request',
      () async {
    final repo = ReminderRepo()..timeout = true;
    final controller = PatientDoseReminderController(repo, clock: () => now)
      ..select('mother');
    await controller.send(key);
    repo.timeout = false;
    repo.pending = Completer();
    final pending = controller.send(key);
    await controller.send(key);
    expect(repo.sent.length, 2);
    expect(repo.sent[0], repo.sent[1]);
    repo.pending!.complete(ReminderReceipt(1, 'mother', 2, key.$2, now,
        now.add(const Duration(minutes: 10)), 'accepted'));
    await pending;
    expect(controller.message(key), 'Đã gửi yêu cầu nhắc');
    expect(controller.wait(key), const Duration(minutes: 10));
    controller.dispose();
  });
  test('server Retry-After determines countdown and clears on patient switch',
      () async {
    final repo = ReminderRepo()..cooldown = const Duration(seconds: 17);
    final controller = PatientDoseReminderController(repo, clock: () => now)
      ..select('mother');
    await controller.send(key);
    expect(controller.wait(key), const Duration(seconds: 17));
    controller.select('father');
    expect(controller.wait(key), Duration.zero);
    expect(controller.receipt(key), isNull);
    controller.dispose();
  });
  test('late send response cannot restore previous patient state', () async {
    final repo = ReminderRepo()..pending = Completer();
    final controller = PatientDoseReminderController(repo, clock: () => now)
      ..select('mother');
    final pending = controller.send(key);
    await Future<void>.delayed(Duration.zero);
    controller.select(null);
    repo.pending!.complete(
        ReminderReceipt(1, 'mother', 2, key.$2, now, now, 'accepted'));
    await pending;
    expect(controller.receipt(key), isNull);
    expect(controller.message(key), isNull);
    controller.dispose();
  });
}
