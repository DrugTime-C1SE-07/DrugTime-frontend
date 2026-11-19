import 'dart:async';

// Nối mức phiên trong app.dart (AC12, AC13, AC14c): thu hồi ai_meal hoặc đăng xuất thì thực đơn
// trong bộ nhớ, món đã chọn và dữ liệu widget đều được xóa.
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/repositories/consent_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_choice_store.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_widget_bridge.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_scope.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_test_helpers.dart';

/// Consent giả đổi được trạng thái ai_meal khi thu hồi.
class _Consents implements ConsentRepository {
  bool aiMeal = true;

  List<ConsentState> _all() => [
        for (final p in ConsentPurpose.values)
          ConsentState(
            purpose: p,
            granted: p == ConsentPurpose.aiMeal ? aiMeal : true,
            documentVersion: 'v',
            currentDocumentVersion: 'v',
          ),
      ];

  @override
  Future<List<ConsentState>> fetchAll() async => _all();

  @override
  Future<ConsentState> grant(ConsentPurpose purpose) async {
    if (purpose == ConsentPurpose.aiMeal) aiMeal = true;
    return _all().firstWhere((s) => s.purpose == purpose);
  }

  @override
  Future<ConsentState> withdraw(ConsentPurpose purpose) async {
    if (purpose == ConsentPurpose.aiMeal) aiMeal = false;
    return _all().firstWhere((s) => s.purpose == purpose);
  }
}

class _Links implements MealWidgetLinkSource {
  _Links(this.first);
  final MealWidgetLink? first;
  final controller = StreamController<MealWidgetLink>.broadcast();

  @override
  Future<MealWidgetLink?> initial() async => first;

  @override
  Stream<MealWidgetLink> get links => controller.stream;
}

void main() {
  late MemoryMealChoiceStore store;
  late RecordingWidgetBridge bridge;
  late AuthController auth;
  late _Consents consents;

  Future<MealPlanScope> pumpApp(WidgetTester tester,
      {MealWidgetLinkSource? links}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DietarySession.instance
      ..clear()
      ..restrictions = const DietaryDeclaration.none();
    store = MemoryMealChoiceStore();
    bridge = RecordingWidgetBridge();
    consents = _Consents();
    auth = AuthController(InMemoryAuthRepository(
      initialSession: AuthSession(
        userId: 'u-1',
        accessToken: 'app-token',
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        profileComplete: true,
      ),
      simulatedDelay: Duration.zero,
    ));
    await tester.pumpWidget(DrugTimeApp(
      authController: auth,
      medicationRepository: InMemoryMedicationRepository(),
      consentRepository: consents,
      mealSuggestionRepository: FakeMealRepository()..uniqueIds = true,
      allergyProfileRepository: FakeAllergyRepository(reportedAllergy),
      mealChoiceStore: store,
      mealWidgetBridge: bridge,
      mealWidgetLinkSource: links,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    final scope = MealPlanScope.of(tester.element(find.byType(AppShell)));
    await ConsentScope.read(tester.element(find.byType(AppShell))).load();
    await scope.plan.loadAllergy();
    await scope.plan.analyze();
    await scope.choices.choose(
        MealType.trua,
        const MealChoice(
            name: 'Cơm gạo lứt', kcal: 480, suggestionId: 1, dishIndex: 0));
    await tester.pumpAndSettle();
    expect(scope.plan.hasMenu, isTrue);
    expect(store.data.containsKey('u-1'), isTrue);
    return scope;
  }

  testWidgets('thu hồi ai_meal: xóa thực đơn, món đã chọn, widget về empty',
      (tester) async {
    final scope = await pumpApp(tester);
    await ConsentScope.read(tester.element(find.byType(AppShell)))
        .withdraw(ConsentPurpose.aiMeal);
    await tester.pumpAndSettle();
    expect(scope.plan.hasMenu, isFalse);
    expect(scope.choices.hasAny, isFalse);
    expect(store.data, isEmpty);
    expect(bridge.published.last.state, TodayMenuState.empty);
  });

  testWidgets('đăng xuất: xóa thực đơn, món đã chọn, widget về signed_out',
      (tester) async {
    final scope = await pumpApp(tester);
    await auth.signOut();
    // Màn đăng nhập có linh vật chuyển động liên tục: không chờ settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(scope.plan.hasMenu, isFalse);
    expect(scope.plan.patientId, isNull);
    expect(scope.choices.hasAny, isFalse);
    expect(store.data, isEmpty);
    expect(bridge.published.last.state, TodayMenuState.signedOut);
  });

  testWidgets(
      'mở app từ widget ở bữa Tối: vào màn gợi ý tab Tối, không gọi lại API (AC14d)',
      (tester) async {
    final links = _Links(null);
    final scope = await pumpApp(tester, links: links);
    links.controller.add(const MealWidgetLink(meal: MealType.toi));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final screen =
        tester.widget<MealSuggestionScreen>(find.byType(MealSuggestionScreen, skipOffstage: false));
    expect(screen.initialMeal, MealType.toi);
    expect(scope.plan.tab, MealType.toi);
    await links.controller.close();
  });
}
