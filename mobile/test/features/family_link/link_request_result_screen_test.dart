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
  });

  testWidgets('R0: đang chờ → không liệt kê mục xem được', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LinkRequestResultScreen(outcome: LinkSubmitOutcome.waiting)));
    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
    expect(find.byKey(const Key('link-result-scopes')), findsNothing);
    expect(find.text('Chưa có quyền xem dữ liệu'), findsOneWidget);
  });
}
