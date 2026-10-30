import 'dart:async';

import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/caregiver_failure.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/incoming_link_request.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_consent_confirmation_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/incoming_requests_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/widgets/incoming_requests_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyUserId = 'caregiver-uuid-001';

IncomingLinkRequest buildTestRequest({
  int linkId = 10,
  String familyUserId = _familyUserId,
  String? name = 'Nguyễn Văn An',
  String? phone = '0901234567',
  String? email = 'an.nguyen@example.com',
  DateTime? requestedAt,
}) =>
    IncomingLinkRequest(
      linkId: linkId,
      familyUserId: familyUserId,
      familyName: name,
      requestedAt: requestedAt ?? DateTime.utc(2026, 10, 20, 3, 30),
      familyPhone: phone,
      familyEmail: email,
    );

void main() {
  group('Task 3.17 - LinkConsentConfirmationScreen', () {
    testWidgets('Màn xác nhận hiển thị đầy đủ tên, SĐT, Email và giờ Việt Nam',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final req = buildTestRequest(
        phone: '0901234567',
        email: 'an.nguyen@example.com',
      );
      final repo = InMemoryCaregiverRepository(pending: [req]);
      final controller = IncomingRequestsController(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: LinkConsentConfirmationScreen(
            args: LinkConsentConfirmationArgs(
              request: req,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Thông tin người xin liên kết
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('SĐT: 0901234567'), findsOneWidget);
      expect(find.text('Email: an.nguyen@example.com'), findsOneWidget);
      // 03:30 UTC = 10:30 UTC+7 (giờ Việt Nam)
      expect(find.text('Gửi lúc 10:30 20/10/2026'), findsOneWidget);

      // Mục đích chia sẻ
      expect(find.byKey(const Key('consent-purpose-card')), findsOneWidget);
      expect(
        find.textContaining('Cho phép người thân đồng hành'),
        findsOneWidget,
      );

      // Danh sách dữ liệu chia sẻ
      expect(find.text('Lịch sử tuân thủ'), findsOneWidget);
      expect(find.text('Danh sách thuốc'), findsOneWidget);
      expect(find.text('Cảnh báo bỏ lỡ liều'), findsOneWidget);

      // Quyền kiểm soát & Rút quyền (QD-30)
      expect(find.byKey(const Key('consent-revocation-card')), findsOneWidget);
      expect(find.textContaining('Tắt chia sẻ tạm thời'), findsOneWidget);
      expect(find.textContaining('Gỡ liên kết'), findsOneWidget);
      expect(
        find.textContaining('không thể thu hồi lại'),
        findsOneWidget,
      );

      // Hai nút ngang hàng, không có checkbox tick sẵn
      expect(find.byKey(const Key('consent-confirm-approve')), findsOneWidget);
      expect(find.byKey(const Key('consent-confirm-reject')), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('Khi SĐT và Email null thì chỉ hiển thị thông tin có sẵn, không tự suy đoán',
        (tester) async {
      final req = buildTestRequest(phone: null, email: null);
      final repo = InMemoryCaregiverRepository(pending: [req]);
      final controller = IncomingRequestsController(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: LinkConsentConfirmationScreen(
            args: LinkConsentConfirmationArgs(
              request: req,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('consent-requester-phone')), findsNothing);
      expect(find.byKey(const Key('consent-requester-email')), findsNothing);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
    });

    testWidgets('Đóng màn bằng nút close hoặc back không bao giờ tự đồng ý (yêu cầu vẫn pending)',
        (tester) async {
      final req = buildTestRequest();
      final repo = InMemoryCaregiverRepository(pending: [req]);
      final controller = IncomingRequestsController(repo);

      bool? result = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await LinkConsentConfirmationScreen.show(
                  context,
                  request: req,
                  controller: controller,
                );
              },
              child: const Text('Mở xác nhận'),
            ),
          ),
        ),
      );

      // Mở màn hình
      await tester.tap(find.text('Mở xác nhận'));
      await tester.pumpAndSettle();

      expect(find.byType(LinkConsentConfirmationScreen), findsOneWidget);

      // Bấm nút đóng
      await tester.tap(find.byKey(const Key('consent-confirm-close')));
      await tester.pumpAndSettle();

      // Kết quả đóng màn không phải true, không gọi approve
      expect(result, isFalse);
      expect(repo.calls.where((c) => c.startsWith('approve')), isEmpty);
    });

    testWidgets('Approve thành công: gọi API kèm đúng documentVersion và làm mới người giám sát',
        (tester) async {
      final req = buildTestRequest();
      final repo = InMemoryCaregiverRepository(pending: [req]);
      bool refreshed = false;
      final controller = IncomingRequestsController(
        repo,
        onLinkedCaregiversChanged: () => refreshed = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkConsentConfirmationScreen(
              args: LinkConsentConfirmationArgs(
                request: req,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm Đồng ý
      await tester.tap(find.byKey(const Key('consent-confirm-approve')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Kiểm tra gọi API approve kèm documentVersion
      expect(repo.approvals.single, (
        linkId: 10,
        familyUserId: _familyUserId,
        documentVersion: ConsentPurpose.familySharing.documentVersion,
      ));
      expect(refreshed, isTrue);

      // Thông báo SnackBar tiếng Việt
      expect(find.text('Đã đồng ý yêu cầu liên kết của Nguyễn Văn An.'), findsOneWidget);
    });

    testWidgets('Reject thành công: có dialog xác nhận, hủy không gọi, xác nhận gọi reject',
        (tester) async {
      final req = buildTestRequest();
      final repo = InMemoryCaregiverRepository(pending: [req]);
      bool refreshed = false;
      final controller = IncomingRequestsController(
        repo,
        onLinkedCaregiversChanged: () => refreshed = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkConsentConfirmationScreen(
              args: LinkConsentConfirmationArgs(
                request: req,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm Từ chối
      await tester.tap(find.byKey(const Key('consent-confirm-reject')));
      await tester.pumpAndSettle();

      // Hộp xác nhận xuất hiện
      expect(find.byKey(const Key('reject-confirm-dialog')), findsOneWidget);

      // Bấm Hủy trong dialog
      await tester.tap(find.byKey(const Key('reject-dialog-cancel')));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('reject')), isEmpty);

      // Bấm Từ chối lại và xác nhận
      await tester.tap(find.byKey(const Key('consent-confirm-reject')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reject-dialog-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.calls, contains('reject:10'));
      expect(refreshed, isTrue);
      expect(find.text('Đã từ chối yêu cầu của Nguyễn Văn An.'), findsOneWidget);
    });

    testWidgets('Đang gửi thao tác thì khóa cả hai nút chống bấm đúp',
        (tester) async {
      final req = buildTestRequest();
      final gate = Completer<void>();
      final repo = InMemoryCaregiverRepository(pending: [req], failures: [gate]);
      final controller = IncomingRequestsController(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkConsentConfirmationScreen(
              args: LinkConsentConfirmationArgs(
                request: req,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm Đồng ý
      await tester.tap(find.byKey(const Key('consent-confirm-approve')));
      await tester.pump();

      // Hai nút đều bị khóa (onPressed == null)
      final approveBtn = tester.widget<FilledButton>(find.byKey(const Key('consent-confirm-approve')));
      final rejectBtn = tester.widget<OutlinedButton>(find.byKey(const Key('consent-confirm-reject')));
      expect(approveBtn.onPressed, isNull);
      expect(rejectBtn.onPressed, isNull);

      // Thử bấm lại không phát sinh thêm call
      await tester.tap(find.byKey(const Key('consent-confirm-approve')), warnIfMissed: false);
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      expect(repo.calls.where((c) => c.startsWith('approve')), hasLength(1));
    });

    for (final s in [
      (CaregiverFailureKind.conflict, 'Đã có thay đổi, đang tải lại.'),
      (CaregiverFailureKind.forbidden, 'Bạn không có quyền thực hiện thao tác này'),
      (CaregiverFailureKind.network, 'Không kết nối được máy chủ'),
      (CaregiverFailureKind.consentRequired, 'Cần bật "Chia sẻ với người thân"'),
    ]) {
      testWidgets('Xử lý lỗi ${s.$1.name}: hiển thị thông báo tiếng Việt tương ứng',
          (tester) async {
        final req = buildTestRequest();
        final repo = InMemoryCaregiverRepository(
          pending: [req],
          failures: [CaregiverFailure(s.$1)],
        );
        final controller = IncomingRequestsController(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LinkConsentConfirmationScreen(
                args: LinkConsentConfirmationArgs(
                  request: req,
                  controller: controller,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('consent-confirm-approve')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining(s.$2), findsOneWidget);
      });
    }
  });

  group('Task 3.17 - IncomingRequestsSection & Badge States', () {
    testWidgets('Hiển thị trạng thái loading khi đang tải lần đầu',
        (tester) async {
      final gate = Completer<void>();
      final repo = InMemoryCaregiverRepository(failures: [gate]);
      final controller = IncomingRequestsController(repo);
      unawaited(controller.load()); // Đang chờ gate hoàn thành

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomingRequestsSection(
              controller: controller,
              sharingConsentGranted: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('incoming-requests-loading')), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Hiển thị trạng thái offline khi mất mạng', (tester) async {
      final repo = InMemoryCaregiverRepository(failures: [
        const CaregiverFailure(CaregiverFailureKind.network),
      ]);
      final controller = IncomingRequestsController(repo);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomingRequestsSection(
              controller: controller,
              sharingConsentGranted: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incoming-requests-offline')), findsOneWidget);
      expect(find.text('Không có kết nối mạng'), findsOneWidget);
      expect(find.byKey(const Key('incoming-retry-offline')), findsOneWidget);
    });

    testWidgets('Hiển thị trạng thái rỗng khi showWhenEmpty = true',
        (tester) async {
      final repo = InMemoryCaregiverRepository(pending: const []);
      final controller = IncomingRequestsController(repo);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomingRequestsSection(
              controller: controller,
              sharingConsentGranted: true,
              showWhenEmpty: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incoming-requests-empty')), findsOneWidget);
    });

    testWidgets('Badge đếm đúng số yêu cầu pending và cập nhật khi duyệt/từ chối',
        (tester) async {
      final req1 = buildTestRequest(linkId: 1);
      final req2 = buildTestRequest(linkId: 2);
      final repo = InMemoryCaregiverRepository(pending: [req1, req2]);
      final controller = IncomingRequestsController(repo);
      await controller.load();

      expect(controller.pendingCount, 2);

      // Approve 1 yêu cầu
      await controller.approve(req1);
      expect(controller.pendingCount, 1);

      // Reject yêu cầu còn lại
      await controller.reject(req2);
      expect(controller.pendingCount, 0);
      expect(controller.isEmpty, isTrue);
    });
  });
}
