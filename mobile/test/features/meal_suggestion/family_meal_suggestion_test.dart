import 'dart:typed_data';

import 'package:drugtime_mobile/features/meal_suggestion/data/meal_choice_store.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_widget_bridge.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/repositories/family_meal_suggestion_repository.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_choice_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

void main() {
  test('TC-03: DietarySession.isolated is separate from DietarySession.instance',
      () {
    DietarySession.instance
      ..clear()
      ..restrictions = const DietaryDeclaration.items(['Ít muối'])
      ..preferences = const ['Chay'];
    final isolated = DietarySession.isolated();
    expect(isolated.isDeclared, isFalse);
    isolated.restrictions = const DietaryDeclaration.none();
    expect(DietarySession.instance.restrictions!.items, ['Ít muối']);
  });

  test('TC-05: MealChoiceController readOnly never mutates choices or widget',
      () async {
    final store = MemoryMealChoiceStore();
    final bridge = RecordingWidgetBridge();
    final c = MealChoiceController(store: store, bridge: bridge, readOnly: true);
    await c.bind('mother');
    await c.choose(
      MealType.trua,
      const MealChoice(name: 'Phở', kcal: 400, suggestionId: 1, dishIndex: 0),
    );
    expect(c.hasAny, isFalse);
    expect(bridge.published, isEmpty);
  });

  test('TC-06 & TC-07: FamilyMealSuggestionRepository enforces MOCK(6.11) scope & 403',
      () async {
    MealFailureKind? nextError;
    final repo = FamilyMealSuggestionRepository(
      accessCheck: (patientId) => nextError,
    );
    final res = await repo.suggest(
      patientId: 'mother',
      mealType: MealType.trua,
      allergies: const DietaryDeclaration.none(),
      restrictions: const DietaryDeclaration.none(),
    );
    expect(res.disclaimer.trim(), isNotEmpty);
    expect(res.dishes, isNotEmpty);

    nextError = MealFailureKind.consentRevoked;
    await expectLater(
      repo.suggest(
        patientId: 'mother',
        mealType: MealType.trua,
        allergies: const DietaryDeclaration.none(),
        restrictions: const DietaryDeclaration.none(),
      ),
      throwsA(predicate<MealSuggestionFailure>(
          (e) => e.kind == MealFailureKind.consentRevoked)),
    );

    nextError = MealFailureKind.forbidden;
    await expectLater(
      repo.suggest(
        patientId: 'mother',
        mealType: MealType.trua,
        allergies: const DietaryDeclaration.none(),
        restrictions: const DietaryDeclaration.none(),
      ),
      throwsA(predicate<MealSuggestionFailure>(
          (e) => e.kind == MealFailureKind.forbidden)),
    );
  });

  test('TC-08: FamilyMealSuggestionRepository delegates to remote when supplied',
      () async {
    final remote = FakeMealRepository();
    final repo = FamilyMealSuggestionRepository(remote: remote);
    final res = await repo.suggest(
      patientId: 'mother',
      mealType: MealType.sang,
      allergies: const DietaryDeclaration.none(),
      restrictions: const DietaryDeclaration.none(),
    );
    expect(res.mealType, MealType.sang);
    expect(remote.calls, hasLength(1));
  });

  testWidgets(
      'TC-09..TC-13: caregiverMode is read-only, displays disclaimer, clears & shows R8 on 403',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = FakeMealRepository()..uniqueIds = true;
    final session = DietarySession.isolated()
      ..restrictions = const DietaryDeclaration.none();
    final plan = MealPlanController(
      repository: repo,
      allergyRepository: FakeAllergyRepository(reportedAllergy),
      session: session,
      now: () => DateTime.utc(2026, 11, 16, 4, 30),
    );
    final choices = MealChoiceController(
      store: MemoryMealChoiceStore(),
      readOnly: true,
    );
    final deniedCalls = <MealFailureKind>[];
    await tester.pumpWidget(
      MealPlanScope(
        plan: plan,
        choices: choices,
        child: MaterialApp(
          home: MealSuggestionScreen(
            patientId: 'mother',
            patientName: 'Mẹ Hoa',
            caregiverMode: true,
            onAccessDenied: (f) => deniedCalls.add(f.kind),
            onDeclareAllergy: (_) async =>
                throw StateError('QD-27 must not declare allergy'),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fm-meal-readonly-chip')), findsOneWidget);
    expect(find.textContaining('cho Mẹ Hoa'), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-disclaimer')), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-0')), findsNothing);
    expect(find.byKey(const ValueKey('detail-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-choose')), findsNothing);
    expect(find.byKey(const ValueKey('meal-disclaimer')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    repo.responses.add(const MealSuggestionFailure(MealFailureKind.forbidden));
    final refreshFinder = find.byKey(const ValueKey('refresh'));
    await tester.ensureVisible(refreshFinder);
    await tester.pumpAndSettle();
    await tester.tap(refreshFinder);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(plan.hasMenu, isFalse);
    expect(deniedCalls, [MealFailureKind.forbidden]);
    expect(find.byKey(const ValueKey('meal-denied-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('retry')), findsNothing);
  });

  testWidgets('TC-16: patient unreported allergy in caregiverMode blocks API read-only',
      (tester) async {
    final repo = FakeMealRepository()..uniqueIds = true;
    final session = DietarySession.isolated()
      ..restrictions = const DietaryDeclaration.none();
    final plan = MealPlanController(
      repository: repo,
      allergyRepository: FakeAllergyRepository(const AllergyProfile.unreported()),
      session: session,
      now: () => DateTime.utc(2026, 11, 16, 4, 30),
    );
    final choices = MealChoiceController(
      store: MemoryMealChoiceStore(),
      readOnly: true,
    );
    await tester.pumpWidget(
      MealPlanScope(
        plan: plan,
        choices: choices,
        child: MaterialApp(
          home: MealSuggestionScreen(
            patientId: 'mother',
            patientName: 'Mẹ Hoa',
            caregiverMode: true,
            onDeclareAllergy: (_) async =>
                throw StateError('QD-27 must not declare allergy'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.byKey(const ValueKey('declare-allergy')), findsNothing);
    expect(find.byKey(const ValueKey('fm-meal-unreported-allergy')),
        findsOneWidget);
  });

  testWidgets(
      'TC-13: 403 consentRevoked clears memory and re-checks live on reopen without cached permission',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = FakeMealRepository()..uniqueIds = true;
    repo.responses.addAll([
      const MealSuggestionFailure(MealFailureKind.consentRevoked),
      const MealSuggestionFailure(MealFailureKind.consentRevoked),
      const MealSuggestionFailure(MealFailureKind.consentRevoked),
    ]);
    MealPlanController makePlan() => MealPlanController(
          repository: repo,
          allergyRepository: FakeAllergyRepository(reportedAllergy),
          session: DietarySession.isolated(),
          now: () => DateTime.utc(2026, 11, 16, 4, 30),
        );
    final deniedCalls = <MealFailureKind>[];
    final choices = MealChoiceController(
        store: MemoryMealChoiceStore(), readOnly: true);

    await tester.pumpWidget(
      MealPlanScope(
        plan: makePlan(),
        choices: choices,
        child: MaterialApp(
          home: MealSuggestionScreen(
            key: const ValueKey('open-1'),
            patientId: 'mother',
            patientName: 'Mẹ Hoa',
            caregiverMode: true,
            onAccessDenied: (f) => deniedCalls.add(f.kind),
            onDeclareAllergy: (_) async => false,
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(deniedCalls, [MealFailureKind.consentRevoked]);
    expect(find.byKey(const ValueKey('meal-denied-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('retry')), findsNothing);
    final callsAfterRevoke = repo.calls.length;

    // Reopen fresh (permission restored on server -> fresh live call succeeds, CD4 no cache)
    await tester.pumpWidget(
      MealPlanScope(
        plan: makePlan(),
        choices: choices,
        child: MaterialApp(
          home: MealSuggestionScreen(
            key: const ValueKey('open-2'),
            patientId: 'mother',
            patientName: 'Mẹ Hoa',
            caregiverMode: true,
            onDeclareAllergy: (_) async => false,
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(repo.calls.length, greaterThan(callsAfterRevoke));
    expect(find.byKey(const ValueKey('fm-meal-readonly-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-disclaimer')), findsOneWidget);
  });

  test(
      'TC-17: FamilyMealSuggestionRepository 3-state foodCheck, refreshLimit, image fallbacks, allergy 403',
      () async {
    final warnRepo = FamilyMealSuggestionRepository(
      foodCheckStatus: FoodCheckStatus.coTuongTac,
      refreshesRemaining: 1,
    );
    final first = await warnRepo.suggest(
      patientId: 'mother',
      mealType: MealType.trua,
      allergies: const DietaryDeclaration.none(),
      restrictions: const DietaryDeclaration.none(),
    );
    expect(first.foodCheck.status, FoodCheckStatus.coTuongTac);
    expect(first.foodCheck.warnings, isNotEmpty);

    final refreshed = await warnRepo.suggest(
      patientId: 'mother',
      mealType: MealType.trua,
      allergies: const DietaryDeclaration.none(),
      restrictions: const DietaryDeclaration.none(),
      previousSuggestionId: first.suggestionId,
    );
    expect(refreshed.refreshesRemaining, 0);
    await expectLater(
      warnRepo.suggest(
        patientId: 'mother',
        mealType: MealType.trua,
        allergies: const DietaryDeclaration.none(),
        restrictions: const DietaryDeclaration.none(),
        previousSuggestionId: refreshed.suggestionId,
      ),
      throwsA(predicate<MealSuggestionFailure>(
          (e) => e.kind == MealFailureKind.refreshLimit)),
    );

    final unknownRepo = FamilyMealSuggestionRepository(
      foodCheckStatus: FoodCheckStatus.khongDuDuLieu,
    );
    final unk = await unknownRepo.suggest(
      patientId: 'mother',
      mealType: MealType.toi,
      allergies: const DietaryDeclaration.none(),
      restrictions: const DietaryDeclaration.none(),
    );
    expect(unk.foodCheck.status, FoodCheckStatus.khongDuDuLieu);
    expect(await unknownRepo.imageStates([1]), isEmpty);
    await expectLater(
      unknownRepo.imageBytes(
          const MealDishImage(imageId: 1, status: MealImageStatus.failed)),
      throwsA(predicate<MealSuggestionFailure>(
          (e) => e.kind == MealFailureKind.unknown)),
    );

    final remote = FakeMealRepository();
    final withRemote = FamilyMealSuggestionRepository(remote: remote);
    expect(await withRemote.imageStates([9]), isEmpty);
    expect(remote.imageCalls, [
      [9]
    ]);
    await expectLater(
      withRemote.imageBytes(
          const MealDishImage(imageId: 9, status: MealImageStatus.ready, url: '/meal-images/9')),
      completes,
    );

    MealFailureKind? allergyDenied = MealFailureKind.forbidden;
    final allergyRepo = FamilyAllergyProfileRepository(
      patientId: 'mother',
      accessCheck: (_) => allergyDenied,
    );
    await expectLater(
      allergyRepo.load(),
      throwsA(predicate<MealSuggestionFailure>(
          (e) => e.kind == MealFailureKind.forbidden)),
    );
    allergyDenied = null;
    expect((await allergyRepo.load()).status, AllergyStatus.noneKnown);
  });

  test(
      'TC-18: MealChoiceController readOnly guards attachThumbnail, unchoose, clear, signOut',
      () async {
    final store = MemoryMealChoiceStore();
    final bridge = RecordingWidgetBridge();
    final c = MealChoiceController(store: store, bridge: bridge, readOnly: true);
    await c.bind('mother');
    await c.bind('mother'); // same id _rollDay branch
    const choice = MealChoice(
        name: 'Cháo', kcal: 300, suggestionId: 1, dishIndex: 0, imageId: 1);
    await c.attachThumbnail(
        MealType.sang, choice, Uint8List.fromList([1, 2, 3]));
    await c.unchoose(MealType.sang);
    await c.clear();
    await c.signOut();
    expect(c.hasAny, isFalse);
    expect(bridge.published, isEmpty);
    expect(bridge.thumbnails, isEmpty);
    c.dispose();
  });

  test('TC-19: validateDietaryItems covers limits, blanks, duplicates', () {
    expect(validateDietaryItems(['a', 'b'], max: 1), isNotNull);
    expect(validateDietaryItems(['  '], max: 5), isNotNull);
    expect(validateDietaryItems(['a' * 41], max: 5), isNotNull);
    expect(validateDietaryItems(['Tôm', 'tôm'], max: 5), isNotNull);
    expect(validateDietaryItems(['Ít muối', 'Ít đường'], max: 5), isNull);
  });

  test(
      'TC-20: MealChoiceController bind(null), publish, attachThumbnail match & mismatch',
      () async {
    final store = MemoryMealChoiceStore();
    final bridge = RecordingWidgetBridge();
    final c = MealChoiceController(store: store, bridge: bridge);
    await c.bind('u1');
    const c1 = MealChoice(name: 'Cháo', kcal: 300, suggestionId: 1, dishIndex: 0);
    const c2 = MealChoice(name: 'Phở', kcal: 400, suggestionId: 2, dishIndex: 1);
    await c.choose(MealType.sang, c1);
    final png = Uint8List.fromList([1, 2, 3]);
    await c.attachThumbnail(MealType.sang, c2, png); // mismatch ignored
    expect(bridge.thumbnails[MealType.sang], isNull);
    await c.attachThumbnail(MealType.sang, c1, png); // match saved
    expect(bridge.thumbnails[MealType.sang], png);
    await c.unchoose(MealType.toi); // absent no-op
    await c.publish();
    await c.bind(null);
    expect(bridge.published.last.state, TodayMenuState.signedOut);
    c.dispose();
  });
}
