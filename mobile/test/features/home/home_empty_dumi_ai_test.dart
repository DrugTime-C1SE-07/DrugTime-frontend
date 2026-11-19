// Trang chủ khi chưa có thuốc: nút "Dumi AI" mở luồng gợi ý bữa ăn (P20b).
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bấm "Dumi AI" đẩy route gợi ý, không còn "chưa khả dụng"',
      (tester) async {
    final pushed = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeScreen(
            displayName: 'Anh Bẻo', onFamily: () {}, onMedications: () {}),
      ),
      onGenerateRoute: (settings) {
        pushed.add(settings.name);
        return MaterialPageRoute<void>(
            settings: settings, builder: (_) => const SizedBox());
      },
    ));
    await tester.pump();
    await tester.tap(find.text('Dumi AI'));
    await tester.pumpAndSettle();
    expect(pushed, [AppRoutes.mealSuggestion]);
    expect(find.text('Dumi AI chưa khả dụng.'), findsNothing);
  });
}
