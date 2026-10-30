import 'dart:async';

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/caregiver.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/caregiver_failure.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/caregivers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_link_test_helpers.dart';

Caregiver caregiver(
  int id, {
  String? name = 'Nguyễn Văn An',
  bool sharing = false,
  DateTime? approvedAt,
  bool legacy = false,
}) =>
    Caregiver(
      linkId: id,
      familyUserId: 'family-$id',
      familyName: name,
      sharingEnabled: sharing,
      // 18:00 UTC ngày 14 = 01:00 ngày 15 giờ Việt Nam.
      approvedAt: legacy ? null : approvedAt ?? DateTime.utc(2026, 10, 14, 18),
    );

void main() {
  const allConsents = {
    ConsentPurpose.healthData,
    ConsentPurpose.familySharing,
    ConsentPurpose.terms,
  };

  Future<InMemoryCaregiverRepository> pumpScreen(
    WidgetTester tester, {
    List<Caregiver>? caregivers,
    List<Object?>? failures,
    Set<ConsentPurpose> consents = allConsents,
  }) async {
    final repo = InMemoryCaregiverRepository(caregivers: caregivers, failures: failures);
    await pumpFamilyLink(
      tester,
      const CaregiversScreen(),
      repository: InMemoryFamilyLinkRepository(),
      caregivers: repo,
      consents: consents,
    );
    await tester.pumpAndSettle();
    return repo;
  }

  bool switchValue(WidgetTester tester, int id) =>
      tester.widget<SwitchListTile>(find.byKey(Key('sharing-$id'))).value;

  bool switchEnabled(WidgetTester tester, int id) =>
      tester.widget<SwitchListTile>(find.byKey(Key('sharing-$id'))).onChanged != null;

  testWidgets('AC20: hiện tên, ngày chấp thuận giờ Việt Nam, công tắc; tên null và liên kết cũ',
      (tester) async {
    final repo = await pumpScreen(tester, caregivers: [
      caregiver(1, sharing: true),
      caregiver(2, name: null, legacy: true),
    ]);

    expect(repo.calls, ['listCaregivers']);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Chấp thuận ngày 15/10/2026'), findsOneWidget);
    expect(find.text('Người dùng DrugTime'), findsOneWidget);
    expect(find.text('Liên kết trước khi có bước xác nhận đồng ý'), findsOneWidget);
    expect(switchValue(tester, 1), isTrue);
    expect(switchValue(tester, 2), isFalse);
    expect(find.byKey(const Key('revoke-1')), findsOneWidget);
  });

  testWidgets('AC20: rỗng thì hiện trạng thái trống; nút đóng màn với openFamilyTab',
      (tester) async {
    Object? result;
    await pumpFamilyLink(
      tester,
      Builder(
        builder: (context) => TextButton(
          key: const Key('launch'),
          onPressed: () async =>
              result = await Navigator.of(context).pushNamed(AppRoutes.caregivers),
          child: const Text('launch'),
        ),
      ),
      repository: InMemoryFamilyLinkRepository(),
      caregivers: InMemoryCaregiverRepository(),
    );
    await tester.tap(find.byKey(const Key('launch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('caregivers-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('caregivers-open-family-tab')));
    await tester.pumpAndSettle();

    expect(find.byType(CaregiversScreen), findsNothing);
    expect(result, CaregiversScreen.openFamilyTab);
  });

  testWidgets('AC20, AC22: kéo xuống và mở lại màn đều gọi lại API (không cache)', (tester) async {
    final repo = await pumpScreen(tester, caregivers: [caregiver(1)]);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.calls, ['listCaregivers', 'listCaregivers']);

    await pumpFamilyLink(
      tester,
      const CaregiversScreen(),
      repository: InMemoryFamilyLinkRepository(),
      caregivers: repo,
    );
    await tester.pumpAndSettle();
    expect(repo.calls, ['listCaregivers', 'listCaregivers', 'listCaregivers']);
  });

  for (final enabled in [true, false]) {
    testWidgets('AC21: gạt công tắc sang $enabled gọi API và hiện giá trị server', (tester) async {
      final repo = await pumpScreen(tester, caregivers: [caregiver(1, sharing: !enabled)]);

      await tester.tap(find.byKey(const Key('sharing-1')));
      await tester.pumpAndSettle();

      expect(repo.calls.last, 'setSharing:1:$enabled');
      expect(switchValue(tester, 1), enabled);
      final verb = enabled ? 'bật' : 'tắt';
      expect(find.text('Đã $verb chia sẻ với Nguyễn Văn An.'), findsOneWidget);
    });
  }

  testWidgets('AC21: đang gửi thì khóa công tắc và nút hủy', (tester) async {
    final gate = Completer<void>();
    final repo = await pumpScreen(tester, caregivers: [caregiver(1)], failures: [null, gate]);

    await tester.tap(find.byKey(const Key('sharing-1')));
    await tester.pump();

    expect(switchEnabled(tester, 1), isFalse);
    expect(tester.widget<TextButton>(find.byKey(const Key('revoke-1'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('sharing-1')), warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('setSharing')), hasLength(1));
    expect(switchEnabled(tester, 1), isTrue);
  });

  testWidgets('AC21: lỗi mạng thì công tắc giữ giá trị cũ và báo lỗi', (tester) async {
    await pumpScreen(
      tester,
      caregivers: [caregiver(1)],
      failures: [null, const CaregiverFailure(CaregiverFailureKind.network)],
    );

    await tester.tap(find.byKey(const Key('sharing-1')));
    await tester.pumpAndSettle();

    expect(switchValue(tester, 1), isFalse);
    expect(find.textContaining('Không kết nối được máy chủ.'), findsOneWidget);
  });

  testWidgets('AC21: gỡ liên kết có xác nhận; giữ liên kết thì không gọi API', (tester) async {
    final repo = await pumpScreen(tester, caregivers: [caregiver(1, sharing: true)]);

    expect(find.text('Gỡ liên kết'), findsOneWidget);
    await tester.tap(find.byKey(const Key('revoke-1')));
    await tester.pumpAndSettle();
    expect(find.text('Gỡ liên kết với người thân?'), findsOneWidget);
    expect(find.textContaining('mất quyền xem thông tin của bạn ngay sau khi liên kết bị gỡ'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('revoke-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('revoke')), isEmpty);

    await tester.tap(find.byKey(const Key('revoke-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('revoke-confirm')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['listCaregivers', 'revoke:1', 'listCaregivers']);
    expect(find.byKey(const Key('caregiver-1')), findsNothing);
    expect(find.text('Đã gỡ liên kết với Nguyễn Văn An.'), findsOneWidget);
  });

  testWidgets('AC19: chưa bật family_sharing: có dải nhắc, không bật được nhưng tắt được',
      (tester) async {
    await pumpScreen(
      tester,
      caregivers: [caregiver(1), caregiver(2, sharing: true)],
      consents: const {ConsentPurpose.healthData, ConsentPurpose.terms},
    );

    expect(find.byKey(const Key('caregivers-consent-banner')), findsOneWidget);
    expect(switchEnabled(tester, 1), isFalse);
    expect(switchEnabled(tester, 2), isTrue);

    await tester.tap(find.byKey(const Key('open-privacy-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacySettingsScreen), findsOneWidget);
  });

  final errors = <CaregiverFailureKind, (String, bool)>{
    // (câu báo, có tải lại danh sách không)
    CaregiverFailureKind.consentRequired: ('Cần bật "Chia sẻ với người thân"', false),
    CaregiverFailureKind.conflict: ('Đã có thay đổi, đang tải lại.', true),
    CaregiverFailureKind.notFound: ('Liên kết không còn tồn tại. Đang tải lại.', true),
    CaregiverFailureKind.confirmationMissing: ('Hãy hủy liên kết', false),
    CaregiverFailureKind.network: ('Không kết nối được máy chủ.', false),
  };
  for (final entry in errors.entries) {
    testWidgets('AC22: bật chia sẻ lỗi ${entry.key.name}', (tester) async {
      final repo = await pumpScreen(
        tester,
        caregivers: [caregiver(1)],
        failures: [null, CaregiverFailure(entry.key)],
      );

      await tester.tap(find.byKey(const Key('sharing-1')));
      await tester.pumpAndSettle();

      final (message, reloads) = entry.value;
      expect(find.textContaining(message), findsOneWidget);
      expect(switchValue(tester, 1), isFalse);
      expect(
        repo.calls,
        ['listCaregivers', 'setSharing:1:true', if (reloads) 'listCaregivers'],
      );
    });
  }

  testWidgets('AC22: tải lần đầu lỗi thì báo lỗi và cho thử lại', (tester) async {
    final repo = await pumpScreen(
      tester,
      caregivers: [caregiver(1)],
      failures: [const CaregiverFailure(CaregiverFailureKind.network)],
    );

    expect(find.byKey(const Key('caregivers-load-error')), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['listCaregivers', 'listCaregivers']);
    expect(find.byKey(const Key('caregiver-1')), findsOneWidget);
  });
}
