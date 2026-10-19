import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/personal_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'profile_test_helpers.dart';
import 'profile_widget_helpers.dart';

void main() {
  testWidgets(
      'six existing assets; pick updates immediately with no network; dismiss preserves',
      (tester) async {
    final repo = FakeProfileRepository();
    final c = ProfileController(repo);
    addTearDown(c.dispose);
    expect(AppAssets.profileAvatars.length, 6);
    for (final asset in AppAssets.profileAvatars) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
    }
    await tester.pumpWidget(profileApp(c, const PersonalProfileScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi ảnh đại diện'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-5')), findsOneWidget);
    final close = find.byKey(const Key('close-avatar-picker'));
    expect(close, findsOneWidget);
    expect(
        tester.widget<FilledButton>(close).style!.backgroundColor!.resolve({}),
        AppColors.brandTint);
    final reads = repo.reads;
    await tester.tap(find.byKey(const ValueKey('avatar-2')));
    await tester.pumpAndSettle();
    expect(c.avatar, AppAssets.profileAvatars[2]);
    expect(repo.reads, reads);
    expect(repo.writes, 0);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == c.avatar),
        findsOneWidget);
    await tester.tap(find.text('Đổi ảnh đại diện'));
    await tester.pumpAndSettle();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(c.avatar, AppAssets.profileAvatars[2]);
    c.clear();
    await tester.pumpAndSettle();
    expect(c.avatar, isNull);
  });
}
