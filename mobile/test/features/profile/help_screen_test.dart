import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/help_screen.dart';

void main() {
  testWidgets('HelpScreen displays FAQ and support contacts correctly', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: HelpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and hero card
    expect(find.text('Trợ giúp & Hỗ trợ'), findsOneWidget);
    expect(find.text('Chúng tôi có thể giúp gì cho bạn?'), findsOneWidget);

    // Verify FAQ items
    expect(find.text('CÂU HỎI THƯỜNG GẶP (FAQ)'), findsOneWidget);
    expect(find.text('Làm thế nào để thêm thuốc vào lịch uống?'), findsOneWidget);

    // Tap to expand FAQ item
    await tester.tap(find.text('Làm thế nào để thêm thuốc vào lịch uống?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chụp quét vỏ thuốc bằng camera (OCR)'), findsOneWidget);

    // Verify Direct Support channels
    expect(find.text('KÊNH HỖ TRỢ TRỰC TIẾP'), findsOneWidget);
    expect(find.text('Email hỗ trợ'), findsOneWidget);
    expect(find.text('hotro@drugtime.vn'), findsOneWidget);
    expect(find.text('Tổng đài tư vấn'), findsOneWidget);
    expect(find.text('1900 8888 (08:00 - 18:00)'), findsOneWidget);

    // Tap support contact shows SnackBar feedback
    await tester.tap(find.text('Email hỗ trợ'));
    await tester.pump();
    expect(find.text('Đã sao chép email: hotro@drugtime.vn'), findsOneWidget);

    // Verify Version footer
    await tester.scrollUntilVisible(find.textContaining('DrugTime Mobile v1.0.0'), 200);
    expect(find.textContaining('DrugTime Mobile v1.0.0'), findsOneWidget);
  });
}
