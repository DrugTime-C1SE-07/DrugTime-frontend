import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';

void main() {
  testWidgets('LoginMobileScreen renders all essential UI components', (WidgetTester tester) async {
    await tester.pumpWidget(const DrugTimeApp());
    await tester.pumpAndSettle();

    // Verify Heading
    expect(find.text('Đăng nhập'), findsOneWidget);

    // Verify Segmented Picker tabs
    expect(find.text('Số điện thoại'), findsNWidgets(2)); // Tab + Input Field Label
    expect(find.text('Email'), findsOneWidget);

    // Verify Phone input prefix
    expect(find.text('+84'), findsOneWidget);

    // Verify Helper text
    expect(find.text('Mã OTP sẽ được gửi qua tin nhắn SMS'), findsOneWidget);

    // Verify Button
    expect(find.text('Gửi mã OTP'), findsOneWidget);

    // Verify Trust Card items
    expect(
      find.text('Bảo mật thông tin sức khỏe theo tiêu chuẩn y tế quốc gia.'),
      findsOneWidget,
    );
    expect(
      find.text('Dữ liệu được mã hóa đầu cuối và không bao giờ chia sẻ với bên thứ ba.'),
      findsOneWidget,
    );

    // Verify Legal text
    expect(find.textContaining('Điều khoản dịch vụ'), findsOneWidget);
    expect(find.textContaining('Chính sách quyền riêng tư'), findsOneWidget);
  });

  testWidgets('Switching between Phone and Email tabs changes the input field', (WidgetTester tester) async {
    await tester.pumpWidget(const DrugTimeApp());
    await tester.pumpAndSettle();

    // Tap on Email tab
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    // Now input label for Email should appear
    expect(find.text('Email'), findsNWidgets(2)); // Tab + Field label
    expect(find.text('Mã OTP sẽ được gửi qua hòm thư điện tử'), findsOneWidget);

    // Switch back to Phone tab
    await tester.tap(find.text('Số điện thoại').first);
    await tester.pumpAndSettle();

    expect(find.text('+84'), findsOneWidget);
    expect(find.text('Mã OTP sẽ được gửi qua tin nhắn SMS'), findsOneWidget);
  });

  testWidgets('Submitting empty input triggers validation error', (WidgetTester tester) async {
    await tester.pumpWidget(const DrugTimeApp());
    await tester.pumpAndSettle();

    // Tap "Gửi mã OTP" without entering anything
    await tester.tap(find.text('Gửi mã OTP'));
    await tester.pumpAndSettle();

    // Error message should be shown
    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
  });
}
