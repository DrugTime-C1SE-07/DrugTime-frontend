import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent_failure.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'consent_test_helpers.dart';

void main() {
  test('load đọc trạng thái từ repository', () async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.aiMeal});
    final controller = ConsentController(repo);

    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.loadError, isNull);
    expect(controller.hasHealthData, isFalse);
    expect(controller.isGranted(ConsentPurpose.aiMeal), isTrue);
  });

  test('load lỗi: giữ loadError, chưa isLoaded', () async {
    final repo = RecordingConsentRepository()
      ..failFetch = const ConsentFailure(ConsentFailureKind.network);
    final controller = ConsentController(repo);

    await controller.load();

    expect(controller.isLoaded, isFalse);
    expect(controller.loadError?.kind, ConsentFailureKind.network);
    expect(controller.isLoading, isFalse);
  });

  test('grant và withdraw cập nhật đúng mục đích, mục khác giữ nguyên', () async {
    final repo = RecordingConsentRepository(granted: {ConsentPurpose.familySharing});
    final controller = ConsentController(repo);
    await controller.load();

    await controller.grant(ConsentPurpose.healthData);
    expect(controller.hasHealthData, isTrue);
    expect(controller.isGranted(ConsentPurpose.familySharing), isTrue);

    await controller.withdraw(ConsentPurpose.familySharing);
    expect(controller.isGranted(ConsentPurpose.familySharing), isFalse);
    expect(controller.hasHealthData, isTrue);
    expect(repo.writes, ['grant:health_data', 'withdraw:family_sharing']);
  });

  test('ghi lỗi: ném ConsentFailure, trạng thái không đổi', () async {
    final repo = RecordingConsentRepository();
    final controller = ConsentController(repo);
    await controller.load();
    repo.failNext = const ConsentFailure(ConsentFailureKind.documentOutdated);

    await expectLater(
      controller.grant(ConsentPurpose.healthData),
      throwsA(isA<ConsentFailure>()),
    );
    expect(controller.hasHealthData, isFalse);
  });

  test('clear bỏ trạng thái của người dùng trước', () async {
    final controller = ConsentController(
      RecordingConsentRepository(granted: {ConsentPurpose.healthData}),
    );
    await controller.load();

    controller.clear();

    expect(controller.isLoaded, isFalse);
    expect(controller.hasHealthData, isFalse);
  });
}
