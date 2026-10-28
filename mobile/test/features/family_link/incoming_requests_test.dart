import 'dart:async';

import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/caregiver_failure.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/incoming_link_request.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_link_test_helpers.dart';

const _an = 'b7dd501a-4ebe-4564-a171-d317710effaa';
const _binh = '3f0c2a9e-7b1d-4e58-9c6a-2d4b8e1f0a73';

IncomingLinkRequest request(int id, {String familyUserId = _an, String? name = 'Nguyễn Văn An', String? phone, String? email}) =>
    IncomingLinkRequest(
      linkId: id,
      familyUserId: familyUserId,
      familyName: name,
      // 02:00 UTC = 09:00 giờ Việt Nam.
      requestedAt: DateTime.utc(2026, 10, 15, 2),
      familyPhone: phone,
      familyEmail: email,
    );

void main() {
  Future<InMemoryCaregiverRepository> pumpTab(
    WidgetTester tester, {
    List<IncomingLinkRequest>? pending,
    List<Object?>? failures,
    Set<ConsentPurpose>? consents,
  }) async {
    final repo = InMemoryCaregiverRepository(pending: pending, failures: failures);
    await pumpFamilyLink(
      tester,
      const FamilyTabScreen(),
      repository: InMemoryFamilyLinkRepository(),
      caregivers: repo,
      consents: consents ??
          const {ConsentPurpose.healthData, ConsentPurpose.familySharing, ConsentPurpose.terms},
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> openApprove(WidgetTester tester, int linkId) async {
    await tester.tap(find.byKey(Key('approve-$linkId')));
    await tester.pumpAndSettle();
  }

  Future<void> confirmApprove(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('consent-confirm-approve')));
    await tester.pumpAndSettle();
  }

  testWidgets('AC16: không có yêu cầu thì không hiện mục, các thẻ cũ vẫn còn', (tester) async {
    final repo = await pumpTab(tester);

    expect(repo.calls, ['listPendingRequests']);
    expect(find.byKey(const Key('incoming-requests')), findsNothing);
    expect(find.byKey(const Key('family-my-code')), findsOneWidget);
  });

  testWidgets('AC16: hiện tên, giờ Việt Nam, tên null dùng tên thay thế', (tester) async {
    await pumpTab(tester, pending: [
      request(2),
      request(1, familyUserId: _binh, name: null),
    ]);

    expect(find.text('Yêu cầu theo dõi bạn (2)'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Người dùng DrugTime'), findsOneWidget);
    expect(find.text('Gửi lúc 09:00 15/10/2026'), findsNWidgets(2));
  });

  testWidgets('AC16: kéo xuống thì tải lại từ server', (tester) async {
    final repo = await pumpTab(tester, pending: [request(1)]);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repo.calls, ['listPendingRequests', 'listPendingRequests']);
  });

  testWidgets('AC17: mở màn xác nhận hiển thị thông tin và hủy thì không gọi API', (tester) async {
    final repo = await pumpTab(tester, pending: [request(1)]);
    await openApprove(tester, 1);

    expect(find.byKey(const Key('consent-requester-name')), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsWidgets);
    expect(find.byKey(const Key('consent-confirm-approve')), findsOneWidget);
    expect(find.byKey(const Key('consent-confirm-reject')), findsOneWidget);

    await tester.tap(find.byKey(const Key('consent-confirm-close')));
    await tester.pumpAndSettle();

    expect(repo.approvals, isEmpty);
    expect(find.byKey(const Key('incoming-request-1')), findsOneWidget);
  });

  testWidgets('AC17: chấp thuận gửi đúng người thân và phiên bản, mục biến mất, hỏi bật chia sẻ',
      (tester) async {
    final repo = await pumpTab(tester, pending: [request(1)]);
    await openApprove(tester, 1);
    await confirmApprove(tester);

    expect(repo.approvals.single,
        (linkId: 1, familyUserId: _an, documentVersion: consentDocumentVersion));
    expect(find.byKey(const Key('incoming-request-1')), findsNothing);
    expect(find.byKey(const Key('enable-sharing-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('enable-sharing-later')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c.startsWith('setSharing')), isEmpty);
    expect(repo.caregivers.single.sharingEnabled, isFalse);
  });

  testWidgets('AC17: chọn Bật chia sẻ gọi API bật chia sẻ', (tester) async {
    final repo = await pumpTab(tester, pending: [request(1)]);
    await openApprove(tester, 1);
    await confirmApprove(tester);

    await tester.tap(find.byKey(const Key('enable-sharing-now')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('setSharing:1:true'));
    expect(repo.caregivers.single.sharingEnabled, isTrue);
    expect(find.text('Đã bật chia sẻ với Nguyễn Văn An.'), findsOneWidget);
  });

  testWidgets('AC18: từ chối có xác nhận; hủy thì không gọi API', (tester) async {
    final repo = await pumpTab(tester, pending: [request(1)]);

    await tester.tap(find.byKey(const Key('reject-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reject-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('reject')), isEmpty);

    await tester.tap(find.byKey(const Key('reject-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reject-confirm')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('reject:1'));
    expect(find.byKey(const Key('incoming-request-1')), findsNothing);
    expect(find.text('Đã từ chối yêu cầu của Nguyễn Văn An.'), findsOneWidget);
  });

  testWidgets('AC19: chưa bật family_sharing thì có dải nhắc mở Quyền riêng tư', (tester) async {
    await pumpTab(
      tester,
      pending: [request(1)],
      consents: const {ConsentPurpose.healthData, ConsentPurpose.terms},
    );

    expect(find.byKey(const Key('incoming-consent-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-privacy-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacySettingsScreen), findsOneWidget);
  });

  testWidgets('AC19: đã bật family_sharing thì không có dải nhắc', (tester) async {
    await pumpTab(tester, pending: [request(1)]);
    expect(find.byKey(const Key('incoming-consent-banner')), findsNothing);
  });

  final errors = <CaregiverFailureKind, String>{
    CaregiverFailureKind.consentRequired: 'Cần bật "Chia sẻ với người thân"',
    CaregiverFailureKind.conflict: 'Đã có thay đổi, đang tải lại.',
    CaregiverFailureKind.notFound: 'Liên kết không còn tồn tại. Đang tải lại.',
    CaregiverFailureKind.documentOutdated: 'Vui lòng cập nhật ứng dụng',
    CaregiverFailureKind.network: 'Không kết nối được máy chủ.',
  };
  for (final entry in errors.entries) {
    testWidgets('AC22: chấp thuận lỗi ${entry.key.name} → báo lỗi và tải lại danh sách',
        (tester) async {
      // Hàng đợi: lần tải đầu bình thường, lần approve lỗi, lần tải lại bình thường.
      final repo = await pumpTab(
        tester,
        pending: [request(1)],
        failures: [null, CaregiverFailure(entry.key)],
      );
      await openApprove(tester, 1);
      await confirmApprove(tester);

      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.byKey(const Key('enable-sharing-dialog')), findsNothing);
      expect(repo.calls, ['listPendingRequests', 'approve:1', 'listPendingRequests']);
      // Lỗi xảy ra trước khi server ghi gì: yêu cầu vẫn nằm trong danh sách.
      expect(find.byKey(const Key('incoming-request-1')), findsOneWidget);
    });
  }

  testWidgets('AC22: đang gửi thì khóa hai nút, bấm lại không gửi thêm', (tester) async {
    final gate = Completer<void>();
    // Lần tải đầu chạy ngay; lần từ chối chờ [gate].
    final repo = await pumpTab(tester, pending: [request(1)], failures: [null, gate]);

    await tester.tap(find.byKey(const Key('reject-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reject-confirm')));
    await tester.pump();

    final approve = tester.widget<FilledButton>(find.byKey(const Key('approve-1')));
    final reject = tester.widget<OutlinedButton>(find.byKey(const Key('reject-1')));
    expect(approve.onPressed, isNull);
    expect(reject.onPressed, isNull);
    await tester.tap(find.byKey(const Key('reject-1')), warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'reject:1'), hasLength(1));
  });
}
