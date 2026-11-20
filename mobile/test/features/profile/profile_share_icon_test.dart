import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/profile/presentation/widgets/profile_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_test_helpers.dart';
import 'profile_widget_helpers.dart';

void main() {
  String iconOf(WidgetTester tester, String tileKey) => tester
      .widget<ProfileIcon>(find.descendant(
          of: find.byKey(Key(tileKey)), matching: find.byType(ProfileIcon)).first)
      .name;

  testWidgets('"Chia sẻ và liên kết" dùng icon chia sẻ, khác "Người giám sát" (AC5)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = ProfileController(FakeProfileRepository());
    addTearDown(c.dispose);
    await tester.pumpWidget(profileApp(c, const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(iconOf(tester, 'share-and-link-tile'), 'h-share');
    expect(iconOf(tester, 'supervisors-tile'), 'h-users');
  });
}
