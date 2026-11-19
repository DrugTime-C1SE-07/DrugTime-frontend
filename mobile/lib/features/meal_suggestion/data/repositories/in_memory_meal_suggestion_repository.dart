import 'dart:typed_data';

import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';

/// Dữ liệu mẫu cho preview và test; không gọi mạng.
class InMemoryMealSuggestionRepository implements MealSuggestionRepository {
  InMemoryMealSuggestionRepository({this.refreshesRemaining = 2});

  int refreshesRemaining;
  int _nextId = 1;

  static const disclaimer =
      'Gợi ý do AI tạo, chỉ mang tính tham khảo, không thay thế tư vấn của bác sĩ hay '
      'chuyên gia dinh dưỡng. Hãy hỏi bác sĩ hoặc dược sĩ trước khi thay đổi chế độ ăn.';

  static MealDish dish(String name,
          {MealDishType type = MealDishType.com, bool isNew = true}) =>
      MealDish(
        name: name,
        dishType: type,
        isNew: isNew,
        tags: const ['Ít muối', 'Nhiều rau'],
        kcalEstimate: 420,
        cookMinutes: 20,
        image: null,
        benefits: const [
          MealBenefit(
              text: 'Ít muối, hợp huyết áp',
              type: 'condition',
              label: 'Tăng huyết áp'),
          MealBenefit(text: 'Nhiều chất xơ', type: 'general'),
        ],
        ingredients: const [
          MealIngredient(
              name: 'Gạo lứt', amount: '60 g', isMain: true, useSparingly: false),
          MealIngredient(
              name: 'Ức gà', amount: '120 g', isMain: true, useSparingly: false),
          MealIngredient(
              name: 'Muối',
              amount: '¼ thìa cà phê',
              isMain: false,
              useSparingly: true),
        ],
      );

  @override
  Future<MealSuggestionResult> suggest({
    required String patientId,
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  }) async {
    if (previousSuggestionId != null) {
      if (refreshesRemaining == 0) {
        throw const MealSuggestionFailure(MealFailureKind.refreshLimit);
      }
      refreshesRemaining--;
    }
    final round = _nextId;
    return MealSuggestionResult(
      suggestionId: _nextId++,
      mealType: mealType,
      dishes: [
        dish('Cơm gạo lứt & ức gà áp chảo $round'),
        dish('Canh bí xanh nấu tôm khô $round', type: MealDishType.monNuoc),
        dish('Đậu hũ sốt cà chua $round', type: MealDishType.monMan),
      ],
      foodCheck: const MealFoodCheck(
          status: FoodCheckStatus.daKiemTraKhongThay, warnings: []),
      disclaimer: disclaimer,
      refreshesRemaining: refreshesRemaining,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<MealDishImage>> imageStates(List<int> imageIds) async => const [];

  @override
  Future<Uint8List> imageBytes(MealDishImage image) async =>
      throw const MealSuggestionFailure(MealFailureKind.unknown);
}
