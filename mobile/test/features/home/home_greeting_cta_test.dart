// Nhận xét 19/11: lời chào một dòng (N3), "Bắt đầu nào!" theo hồ sơ (N1), màn nhỏ (N6).
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';
import 'package:drugtime_mobile/features/home/presentation/home_schedule_controller.dart';
import 'package:drugtime_mobile/features/home/presentation/home_screen.dart'
    as full;
import 'package:drugtime_mobile/features/home/presentation/scene/greeting_name.dart';
import 'package:drugtime_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/presentation/state/medication_controller.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:drugtime_mobile/features/profile/domain/repositories/health_setup_repository.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/health_setup_status_controller.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/profile_test_helpers.dart';

void main() {
  group('greetingLine (AC4)', () {
    test('uses the last word of the Vietnamese full name', () {
      expect(greetingLine('Chào buổi tối', 'Nguyễn Quang Bảo'),
          'Chào buổi tối, Bảo');
      expect(greetingLine('Chào buổi tối', 'Nguyen'), 'Chào buổi tối, Nguyen');
      expect(greetingLine('Chào buổi tối', '  Nguyễn   Văn  Nguyên  '),
          'Chào buổi tối, Nguyên');
    });
    test('no name gives the greeting alone', () {
      expect(greetingLine('Chào buổi tối', null), 'Chào buổi tối');
      expect(greetingLine('Chào buổi tối', '   '), 'Chào buổi tối');
    });
  });

  testWidgets(
      'one line, no underline stroke, long name ellipsized at 130% (AC5)',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
            size: Size(360, 800), textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: SizedBox(
            width: 264, // banner title width: 360 - left 20 - right 76
            child: GreetingTitle(
                greetingLine(
                    'Chào buổi tối', 'Nguyễn Văn Nguyênnnnnnnnnnnnnnnnnn'),
                ink: Colors.white,
                night: true),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.byKey(const Key('home-greeting')));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    // The old highlighter stroke painted a CustomPaint under the name.
    expect(
        find.descendant(
            of: find.byType(GreetingTitle), matching: find.byType(CustomPaint)),
        findsNothing);
  });

  group('"Bắt đầu nào!" on the empty home (AC1, AC2, AC11, AC26)', () {
    Future<void> pump(WidgetTester tester,
        {required _Repo repo, String gender = 'nu'}) async {
      final meds = MedicationController(InMemoryMedicationRepository(seed: []));
      addTearDown(meds.dispose);
      await meds.load();
      final profileRepo = FakeProfileRepository()
        ..value = HealthProfile(fullName: 'Nguyễn Mai', gender: gender);
      final profile = ProfileController(profileRepo);
      addTearDown(profile.dispose);
      await profile.load();
      final setup = HealthSetupStatusController(repo);
      addTearDown(setup.dispose);
      await setup.reload();
      await tester.pumpWidget(ProfileScope(
        controller: profile,
        child: HealthSetupStatusScope(
          controller: setup,
          child: MedicationScope(
            controller: meds,
            child: MaterialApp(
              home: Scaffold(
                body: HomeScreen(onFamily: () {}, onMedications: () {}),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('setup not done shows the button', (tester) async {
      await pump(tester,
          repo: _Repo(physiological: HealthSetupStatus.unreported));
      expect(find.text('Bắt đầu nào!'), findsOneWidget);
    });

    testWidgets('setup done hides the button, the empty card stays',
        (tester) async {
      await pump(tester, repo: _Repo());
      expect(find.text('Bắt đầu nào!'), findsNothing);
      expect(find.text('Chưa có lịch uống thuốc'), findsOneWidget);
    });

    testWidgets('men do not need the physiological step', (tester) async {
      await pump(tester,
          repo: _Repo(physiological: HealthSetupStatus.unreported),
          gender: 'nam');
      expect(find.text('Bắt đầu nào!'), findsNothing);
    });

    testWidgets('a failed read shows no button and no endless skeleton',
        (tester) async {
      await pump(tester, repo: _Repo(fail: true));
      expect(find.text('Bắt đầu nào!'), findsNothing);
      expect(find.text('Chưa có lịch uống thuốc'), findsOneWidget);
    });
  });

  testWidgets('360×640: a dose card is visible without scrolling (AC7)',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final profile = ProfileController(FakeProfileRepository());
    addTearDown(profile.dispose);
    final schedule = _ScheduleWithDoses();
    addTearDown(schedule.dispose);
    await tester.pumpWidget(ProfileScope(
      controller: profile,
      child: MaterialApp(
        home: Scaffold(
          body: HomeScheduleScope(
            controller: schedule,
            child: full.HomeScreen(
                active: true, onFamily: () {}, onSchedule: () {}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.text('Thuốc A').first);
    expect(card.bottom, lessThanOrEqualTo(640));
  });
}

class _ScheduleWithDoses extends HomeScheduleController {
  _ScheduleWithDoses()
      : super(null, null, (_, __) async => HomeConfirmation.synced,
            clock: () => DateTime.utc(2026, 11, 17, 0, 50));

  @override
  Future<void> load() async {
    final doses = [
      for (var i = 0; i < 6; i++)
        HistoryDose(
          medicationId: i,
          medicationName: i == 0 ? 'Thuốc A' : 'Thuốc $i',
          scheduleId: i,
          scheduledAt: DateTime.utc(2026, 11, 17, i + 1),
          takenAt: null,
          status: HistoryDoseStatus.pending,
          statusSource: 'test',
        ),
    ];
    day = DateHistoryGroup(
        DateTime.utc(2026, 11, 17),
        AdherenceSummary(
            total: 6,
            taken: 0,
            late: 0,
            missed: 0,
            pending: 6,
            counted: 6,
            rate: null),
        doses);
    loading = false;
    failed = false;
    notifyListeners();
  }
}

class _Repo implements HealthSetupRepository {
  _Repo({this.physiological = HealthSetupStatus.noneKnown, this.fail = false});
  final HealthSetupStatus physiological;
  final bool fail;

  @override
  Future<HealthSetupSnapshot> read() async {
    if (fail) throw StateError('offline');
    return HealthSetupSnapshot(
        '1',
        const HealthSetupStep(HealthSetupStatus.noneKnown),
        const HealthSetupStep(HealthSetupStatus.noneKnown),
        HealthSetupStep(physiological));
  }

  @override
  Future<List<HealthSetupOption<String>>> allergens() async => const [];

  @override
  Future<List<HealthSetupOption<int>>> conditions() async => const [];

  @override
  Future<HealthSetupSnapshot> save(String revision,
          {HealthSetupStep<String>? allergies,
          HealthSetupStep<int>? conditions,
          HealthSetupStep<int>? physiological}) =>
      read();
}
