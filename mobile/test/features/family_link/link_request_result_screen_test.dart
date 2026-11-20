import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/link_request_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'R0: đã chấp thuận → giải thích chờ bật chia sẻ + 4 mục, không có hồ sơ sức khỏe (AC2)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LinkRequestResultScreen(outcome: LinkSubmitOutcome.accepted)));
    expect(find.text('Đã được chấp thuận'), findsOneWidget);
    expect(
        find.text(
            'Người thân đã đồng ý liên kết. Khi người thân bật chia sẻ, bạn sẽ xem được:'),
        findsOneWidget);
    expect(find.byKey(const Key('link-result-scopes')), findsOneWidget);
    for (final label in [
      'Lịch uống thuốc',
      'Cảnh báo bỏ lỡ liều',
      'Tủ thuốc & tương tác',
      'Lịch sử tuân thủ',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.textContaining('Hồ sơ sức khỏe'), findsNothing);
    expect(find.textContaining('Riêng tư'), findsNothing);
    expect(find.text('Xong'), findsOneWidget);
  });

  testWidgets('R0: đang chờ → không liệt kê mục xem được', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LinkRequestResultScreen(outcome: LinkSubmitOutcome.waiting)));
    expect(find.text('Đang chờ xác nhận'), findsWidgets);
    expect(find.byKey(const Key('link-result-scopes')), findsNothing);
    expect(find.text('Chưa có quyền xem dữ liệu'), findsOneWidget);
  });

  testWidgets(
      'S08-3d: đang chờ → đầy đủ thành phần Figma (badge, recipient card, hủy yêu cầu, về trang chủ)',
      (tester) async {
    bool cancelCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: LinkRequestResultScreen(
        outcome: LinkSubmitOutcome.waiting,
        onCancelRequest: () => cancelCalled = true,
      ),
    ));

    // Status badge
    expect(find.text('Đang chờ duyệt'), findsOneWidget);

    // Thẻ người nhận yêu cầu mặc định
    expect(find.byKey(const Key('link-result-recipient-card')), findsOneWidget);
    expect(find.text('Nguyễn Thị Hoa'), findsOneWidget);
    expect(find.text('TH'), findsOneWidget);
    expect(find.text('Người nhận yêu cầu'), findsOneWidget);

    // Nút Hủy yêu cầu và Về trang chủ
    expect(find.byKey(const Key('link-result-cancel')), findsOneWidget);
    expect(find.byKey(const Key('link-result-done')), findsOneWidget);
    expect(find.text('Về trang chủ'), findsOneWidget);

    // Chạm Hủy yêu cầu mở dialog xác nhận
    await tester.tap(find.byKey(const Key('link-result-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Hủy yêu cầu theo dõi?'), findsOneWidget);
    // Bấm Hủy yêu cầu trong dialog
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy yêu cầu'));
    await tester.pumpAndSettle();

    expect(cancelCalled, isTrue);
  });

  testWidgets('S08-3d: truyền recipientName tùy biến tính đúng initials',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LinkRequestResultScreen(
        outcome: LinkSubmitOutcome.waiting,
        recipientName: 'Trần Văn Bình',
        recipientRole: 'Bố',
      ),
    ));

    expect(find.text('Trần Văn Bình'), findsOneWidget);
    expect(find.text('VB'), findsOneWidget);
    expect(find.text('Bố'), findsOneWidget);
  });
}
