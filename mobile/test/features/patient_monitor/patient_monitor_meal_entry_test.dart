import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/linked_patients_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_controller.dart';
import 'package:drugtime_mobile/features/patient_monitor/presentation/patient_monitor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../meal_suggestion/meal_test_helpers.dart';
import 'patient_monitor_screen_test.dart';

class _TwoPatientRepo extends ScreenRepo {
  _TwoPatientRepo() : super(day: Day.ok);

  @override
  Future<List<LinkedPatient>> patients() async => const [
        LinkedPatient(id: 'mother', name: 'Mẹ Hoa'),
        LinkedPatient(id: 'father', name: 'Bố Bình'),
      ];
}

class _TwoPatientMealRepo extends FakeMealRepository {
  @override
  Future<MealSuggestionResult> suggest({
    required String patientId,
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  }) async {
    await super.suggest(
      patientId: patientId,
      mealType: mealType,
      allergies: allergies,
      restrictions: restrictions,
      preferences: preferences,
      previousSuggestionId: previousSuggestionId,
    );
    return result(
      id: 7000 + calls.length,
      type: mealType,
      dishes: [dish('Món của $patientId ${calls.length}')],
    );
  }
}

void main() {
  testWidgets(
      'TC-01, TC-14: PatientMonitorScreen launches meal UI for patient and clears on revoke',
      (tester) async {
    final controller = await pumpMonitor(tester, ScreenRepo(day: Day.ok));
    expect(find.byKey(const Key('open-meal-suggestion')), findsOneWidget);
    expect(find.text('Gợi ý bữa ăn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-meal-suggestion')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fm-meal-readonly-chip')), findsOneWidget);
    expect(find.text('Mẹ Hoa · chỉ xem'), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-disclaimer')), findsOneWidget);

    // TC-14: revoke while MealSuggestionScreen is open transitions immediately to R8
    controller.revoke('mother');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monitor-lost')), findsOneWidget);
  });

  testWidgets(
      'TC-02: switching patient-a to patient-b in PatientMonitorScreen isolates meal cache',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = _TwoPatientRepo();
    final controller = PatientMonitorController(repo, clock: () => screenNow);
    final invites = InviteLinkController();
    addTearDown(controller.dispose);
    addTearDown(invites.dispose);
    controller.setSession('Nam', available: true);
    await controller.loadHub();
    await controller.select('mother');

    final seenPatientIds = <String>[];
    final mealRepo = _TwoPatientMealRepo()..uniqueIds = true;
    Widget buildFor(String pid) => FamilyLinkScope(
          repository: InMemoryFamilyLinkRepository(),
          caregivers: InMemoryCaregiverRepository(),
          invites: invites,
          monitor: controller,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: PatientMonitorScreen(
              patientId: pid,
              mealRepositoryBuilder: (c) {
                seenPatientIds.add(c.patientId ?? '');
                return mealRepo;
              },
              mealAllergyRepositoryBuilder: (_) =>
                  FakeAllergyRepository(reportedAllergy),
            ),
          ),
        );

    await tester.pumpWidget(buildFor('mother'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-meal-suggestion')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.text('Mẹ Hoa · chỉ xem'), findsOneWidget);
    final motherDish =
        tester.widget<Text>(find.byKey(const ValueKey('dish-name-0'))).data;
    final callsAfterMother = mealRepo.calls.length;

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Switch monitor to father
    await controller.select('father');
    await tester.pumpWidget(buildFor('father'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-meal-suggestion')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(seenPatientIds, ['mother', 'father']);
    expect(mealRepo.calls.length, greaterThan(callsAfterMother));
    expect(find.text('Bố Bình · chỉ xem'), findsOneWidget);
    expect(find.text('Mẹ Hoa · chỉ xem'), findsNothing);
    final fatherDish =
        tester.widget<Text>(find.byKey(const ValueKey('dish-name-0'))).data;
    expect(fatherDish, isNot(motherDish));
  });

  test(
      'TC-04: MealPlanController.bind switches user and isolates DietarySession',
      () async {
    final repo = FakeMealRepository();
    final session = DietarySession.instance
      ..clear()
      ..restrictions = const DietaryDeclaration.none()
      ..preferences = const ['Ít cay'];
    final c = MealPlanController(
      repository: repo,
      allergyRepository: FakeAllergyRepository(reportedAllergy),
      session: session,
      now: () => DateTime.utc(2026, 11, 16, 4, 30),
    )..bind('patient-a');
    await c.loadAllergy();
    await c.analyze();
    expect(c.hasMenu, isTrue);

    c.bind('patient-b');
    expect(c.hasMenu, isFalse);
    expect(c.allergy, isNull);
    expect(c.dietaryDeclared, isFalse);
    c.dispose();
  });
}
