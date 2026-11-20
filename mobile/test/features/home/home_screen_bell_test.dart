import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/home/presentation/home_schedule_controller.dart';
import 'package:drugtime_mobile/features/home/presentation/home_screen.dart' as full;
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import '../profile/profile_test_helpers.dart';

void main() {
  testWidgets('Tapping home notification bell navigates to profile notifications route', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? pushedRoute;

    final profile = ProfileController(FakeProfileRepository());
    addTearDown(profile.dispose);

    final schedule = _ScheduleEmpty();
    addTearDown(schedule.dispose);

    await tester.pumpWidget(
      ProfileScope(
        controller: profile,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            pushedRoute = settings.name;
            if (settings.name == AppRoutes.profileNotifications) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('Notification Preferences Page')),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: HomeScheduleScope(
                  controller: schedule,
                  child: full.HomeScreen(
                    active: true,
                    onFamily: () {},
                    onSchedule: () {},
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Bell button exists
    final bellFinder = find.byKey(const Key('home-notification-bell'));
    expect(bellFinder, findsOneWidget);

    // Tap bell button
    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    // Verify navigated to profile notifications
    expect(pushedRoute, AppRoutes.profileNotifications);
    expect(find.text('Notification Preferences Page'), findsOneWidget);
  });
}

class _ScheduleEmpty extends HomeScheduleController {
  _ScheduleEmpty()
      : super(null, null, (_, __) async => HomeConfirmation.synced,
            clock: () => DateTime.utc(2026, 11, 20, 9, 30));

  @override
  Future<void> load() async {}
}
