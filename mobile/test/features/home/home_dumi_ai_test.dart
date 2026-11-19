// AC1 (task 5.11): bấm "Dumi AI" ở Trang chủ mở màn gợi ý bữa ăn.
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/home/presentation/home_screen.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/profile_test_helpers.dart';

void main() {
  testWidgets('bấm "Dumi AI" đẩy route gợi ý bữa ăn (AC1)', (tester) async {
    final repo = FakeProfileRepository()
      ..value = const HealthProfile(fullName: 'Anh Bẻo');
    final controller = ProfileController(repo);
    addTearDown(controller.dispose);
    final pushed = <String?>[];
    await tester.pumpWidget(ProfileScope(
      controller: controller,
      child: MaterialApp(
        home: Scaffold(
            body: HomeScreen(active: true, onFamily: () {}, onSchedule: () {})),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(
              settings: settings, builder: (_) => const SizedBox());
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dumi AI'));
    await tester.pumpAndSettle();

    expect(pushed, [AppRoutes.mealSuggestion]);
    expect(find.text('Dumi AI đang được phát triển'), findsNothing);
  });
}
