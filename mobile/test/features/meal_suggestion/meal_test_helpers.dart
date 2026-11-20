import 'dart:async';
import 'dart:typed_data';

import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/repositories/consent_repository.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/repositories/allergy_profile_repository.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/repositories/meal_suggestion_repository.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_choice_store.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/meal_widget_bridge.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/screens/meal_suggestion_screen.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_choice_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const disclaimer =
    'Gợi ý do AI tạo, chỉ mang tính tham khảo, không thay thế tư vấn của bác sĩ hay '
    'chuyên gia dinh dưỡng. Hãy hỏi bác sĩ hoặc dược sĩ trước khi thay đổi chế độ ăn.';

const attribution = MealImageAttribution(
  photographerName: 'Nguyễn Văn A',
  photographerUrl: 'https://www.pexels.com/@a',
  sourceUrl: 'https://www.pexels.com/photo/42/',
);

MealDish dish(
  String name, {
  MealDishImage? image,
  bool isNew = true,
  List<MealBenefit>? benefits,
  List<MealIngredient>? ingredients,
}) =>
    MealDish(
      name: name,
      dishType: MealDishType.com,
      isNew: isNew,
      tags: const ['Ít muối'],
      kcalEstimate: 480,
      cookMinutes: 20,
      image: image,
      benefits: benefits ??
          const [
            MealBenefit(
                text: 'Ít muối, tốt cho huyết áp',
                type: 'condition',
                label: 'Tăng huyết áp'),
            MealBenefit(text: 'Nhiều chất xơ', type: 'general'),
          ],
      ingredients: ingredients ??
          const [
            MealIngredient(
                name: 'Gạo lứt',
                amount: '60 g',
                isMain: true,
                useSparingly: false),
            MealIngredient(
                name: 'Ức gà',
                amount: '120 g',
                isMain: true,
                useSparingly: false),
            MealIngredient(
                name: 'Muối',
                amount: '¼ thìa cà phê',
                isMain: false,
                useSparingly: true),
          ],
    );

MealSuggestionResult result({
  int id = 3051,
  MealType type = MealType.trua,
  List<MealDish>? dishes,
  MealFoodCheck foodCheck = const MealFoodCheck(
      status: FoodCheckStatus.daKiemTraKhongThay, warnings: []),
  int refreshesRemaining = 2,
}) =>
    MealSuggestionResult(
      suggestionId: id,
      mealType: type,
      dishes: dishes ??
          [dish('Món A'), dish('Món B'), dish('Món C'), dish('Món D')],
      foodCheck: foodCheck,
      disclaimer: disclaimer,
      refreshesRemaining: refreshesRemaining,
      createdAt: DateTime.utc(2026, 11, 16, 4, 30),
    );

class SuggestCall {
  SuggestCall(this.type, this.allergies, this.restrictions, this.preferences,
      this.previousSuggestionId);

  final MealType type;
  final DietaryDeclaration allergies;
  final DietaryDeclaration restrictions;
  final List<String> preferences;
  final int? previousSuggestionId;
}

/// Repository giả: mỗi lần gọi lấy phản hồi kế tiếp trong hàng đợi (kết quả, lỗi, hoặc Completer).
class FakeMealRepository implements MealSuggestionRepository {
  final calls = <SuggestCall>[];
  final responses = <Object>[];
  final imageCalls = <List<int>>[];
  List<MealDishImage> Function(List<int> ids) imageAnswer = (_) => const [];
  final bytesCalls = <int>[];

  /// `true`: mỗi lời gọi trả một suggestion_id khác nhau (hero tag không trùng giữa các bữa).
  bool uniqueIds = false;

  @override
  Future<MealSuggestionResult> suggest({
    required String patientId,
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  }) async {
    calls.add(SuggestCall(
        mealType, allergies, restrictions, preferences, previousSuggestionId));
    final next = responses.isEmpty
        ? result(id: uniqueIds ? 4000 + calls.length : 3051, type: mealType)
        : responses.removeAt(0);
    if (next is Completer<MealSuggestionResult>) return next.future;
    if (next is MealSuggestionFailure) throw next;
    return next as MealSuggestionResult;
  }

  @override
  Future<List<MealDishImage>> imageStates(List<int> imageIds) async {
    imageCalls.add(imageIds);
    return imageAnswer(imageIds);
  }

  @override
  Future<Uint8List> imageBytes(MealDishImage image) async {
    bytesCalls.add(image.imageId);
    // PNG 1x1 hợp lệ để Image.memory giải mã được.
    return Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0xF8,
      0xCF,
      0xC0,
      0xF0,
      0x1F,
      0x00,
      0x05,
      0x00,
      0x01,
      0xFF,
      0x89,
      0x99,
      0x3D,
      0x1D,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
  }
}

class FakeAllergyRepository implements AllergyProfileRepository {
  FakeAllergyRepository(this.profile);

  AllergyProfile profile;

  @override
  Future<AllergyProfile> load() async => profile;
}

const reportedAllergy = AllergyProfile(
  status: AllergyStatus.reported,
  catalogItems: [AllergyCatalogItem(id: 'shrimp', name: 'Tôm')],
  customItems: ['Đậu phộng'],
);

class FakeConsentRepository implements ConsentRepository {
  FakeConsentRepository({this.aiMeal = true});

  bool aiMeal;
  int fetches = 0;
  int grants = 0;

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
  Future<List<ConsentState>> fetchAll() async {
    fetches++;
    return _all();
  }

  @override
  Future<ConsentState> grant(ConsentPurpose purpose) async {
    grants++;
    if (purpose == ConsentPurpose.aiMeal) aiMeal = true;
    return _all().firstWhere((s) => s.purpose == purpose);
  }

  @override
  Future<ConsentState> withdraw(ConsentPurpose purpose) async =>
      _all().firstWhere((s) => s.purpose == purpose);
}

/// Dựng luồng gợi ý bữa ăn thật (sheet → màn chờ → kết quả) với repository giả, mức phiên.
class FlowHarness {
  FlowHarness({
    FakeMealRepository? repository,
    AllergyProfile allergy = reportedAllergy,
    bool aiMeal = true,
    bool dietaryDeclared = true,
    DateTime? clock,
  })  : repository = repository ?? (FakeMealRepository()..uniqueIds = true),
        allergyRepository = FakeAllergyRepository(allergy),
        consentRepository = FakeConsentRepository(aiMeal: aiMeal),
        clock = clock ?? DateTime.utc(2026, 11, 16, 4, 30) {
    final session = DietarySession.instance..clear();
    if (dietaryDeclared) {
      session
        ..restrictions = const DietaryDeclaration.none()
        ..preferences = const ['Ít cay'];
    }
    plan = MealPlanController(
      repository: this.repository,
      allergyRepository: allergyRepository,
      session: session,
      now: () => this.clock,
    );
    choices = MealChoiceController(
        store: store, bridge: bridge, now: () => this.clock);
  }

  final FakeMealRepository repository;
  final FakeAllergyRepository allergyRepository;
  final FakeConsentRepository consentRepository;
  DateTime clock;
  late final ConsentController consent = ConsentController(consentRepository);
  late final MealPlanController plan;
  late final MealChoiceController choices;
  final store = MemoryMealChoiceStore();
  final bridge = RecordingWidgetBridge();
  final allergyRoutes = <String>[];

  /// What the allergy route returns; `true` simulates a saved declaration.
  bool? declareResult;
  AllergyProfile? allergyAfterDeclare;

  /// Màn "Trang chủ" giả có nút mở luồng.
  Future<void> pump(WidgetTester tester,
      {bool reduceMotion = true, MealType? initialMeal}) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await consent.load();
    await tester.pumpWidget(ConsentScope(
      controller: consent,
      child: MealPlanScope(
        plan: plan,
        choices: choices,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MealSuggestionScreen(
                      patientId: 'patient-1',
                      initialMeal: initialMeal,
                      onDeclareAllergy: (_) async {
                        allergyRoutes.add('allergy');
                        final after = allergyAfterDeclare;
                        if (after != null) allergyRepository.profile = after;
                        return declareResult;
                      },
                    ),
                  )),
                  child: const Text('Mở Dumi'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  /// Bấm mở luồng và chạy hết màn chờ.
  Future<void> openToResults(WidgetTester tester) async {
    await tester.tap(find.text('Mở Dumi'));
    await settle(tester);
  }

  /// Chạy hết các Timer của màn chờ (tối thiểu 2,5 s) rồi chờ ổn định.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
  }
}

class RecordingWidgetBridge implements MealWidgetBridge {
  final published = <TodayMenuSnapshot>[];

  @override
  Future<void> publish(TodayMenuSnapshot snapshot) async =>
      published.add(snapshot);

  final thumbnails = <MealType, Uint8List?>{};
  bool pinSupported = false;
  bool pinOffered = false;
  int pinRequests = 0;

  @override
  Future<void> saveThumbnail(MealType meal, Uint8List? png) async =>
      thumbnails[meal] = png;

  @override
  Future<bool> shouldOfferPin() async => pinSupported && !pinOffered;

  @override
  Future<void> markPinOffered() async => pinOffered = true;

  @override
  Future<void> requestPin() async => pinRequests++;
}
