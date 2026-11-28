import 'dart:typed_data';

import '../../domain/entities/allergy_profile.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/allergy_profile_repository.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';

/// Kiểm tra quyền truy cập dữ liệu bữa ăn cho `MOCK(6.11)` (không cache — bất biến CD4).
typedef FamilyMealAccessCheck = MealFailureKind? Function(String patientId);

/// Lời miễn trừ y khoa mặc định (bất biến CD6).
const kDefaultMealDisclaimer =
    'Gợi ý do AI tạo, chỉ mang tính tham khảo, không thay thế tư vấn của bác sĩ hay '
    'chuyên gia dinh dưỡng. Hãy hỏi bác sĩ hoặc dược sĩ trước khi thay đổi chế độ ăn.';

/// MOCK(6.11): Kho dữ liệu gợi ý bữa ăn phía người thân (Family Member) cho tới khi
/// backend task `6.11` (`POST /patients/{patient_id}/meal-suggestions` theo quyền người thân)
/// được merge.
///
/// Để nối API thật khi `6.11` merge: truyền `remote: RemoteMealSuggestionRepository(api)`
/// (hoặc thay lớp này trực tiếp bằng `RemoteMealSuggestionRepository`).
class FamilyMealSuggestionRepository implements MealSuggestionRepository {
  FamilyMealSuggestionRepository({
    MealSuggestionRepository? remote,
    this.accessCheck,
    this.refreshesRemaining = 2,
    this.foodCheckStatus = FoodCheckStatus.daKiemTraKhongThay,
    DateTime Function()? now,
  })  : _remote = remote,
        _now = now ?? DateTime.now;

  final MealSuggestionRepository? _remote;
  final FamilyMealAccessCheck? accessCheck;
  final int refreshesRemaining;
  final FoodCheckStatus foodCheckStatus;
  final DateTime Function() _now;

  final Map<String, int> _remainingByPatient = {};
  int _nextId = 6150;

  void _enforceAccess(String patientId) {
    final failure = accessCheck?.call(patientId);
    if (failure != null) {
      throw MealSuggestionFailure(failure);
    }
  }

  @override
  Future<MealSuggestionResult> suggest({
    required String patientId,
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  }) async {
    _enforceAccess(patientId);
    final remote = _remote;
    if (remote != null) {
      return remote.suggest(
        patientId: patientId,
        mealType: mealType,
        allergies: allergies,
        restrictions: restrictions,
        preferences: preferences,
        previousSuggestionId: previousSuggestionId,
      );
    }
    var remaining = _remainingByPatient[patientId] ?? refreshesRemaining;
    if (previousSuggestionId != null) {
      if (remaining <= 0) {
        throw const MealSuggestionFailure(MealFailureKind.refreshLimit);
      }
      remaining--;
      _remainingByPatient[patientId] = remaining;
    }
    final round = _nextId++;
    return MealSuggestionResult(
      suggestionId: round,
      mealType: mealType,
      dishes: _dishesFor(mealType, round),
      foodCheck: _foodCheck(),
      disclaimer: kDefaultMealDisclaimer,
      refreshesRemaining: remaining,
      createdAt: _now(),
    );
  }

  MealFoodCheck _foodCheck() => switch (foodCheckStatus) {
        FoodCheckStatus.coTuongTac => const MealFoodCheck(
            status: FoodCheckStatus.coTuongTac,
            warnings: [
              MealFoodWarning(
                foodToAvoid: 'Rau nhiều vitamin K',
                reason: 'Có thể làm giảm tác dụng thuốc đang dùng.',
                severityLevel: 2,
                source: 'Dữ liệu tương tác',
              ),
            ],
          ),
        FoodCheckStatus.daKiemTraKhongThay => const MealFoodCheck(
            status: FoodCheckStatus.daKiemTraKhongThay,
            warnings: [],
          ),
        FoodCheckStatus.khongDuDuLieu => const MealFoodCheck(
            status: FoodCheckStatus.khongDuDuLieu,
            warnings: [],
          ),
      };

  static List<MealDish> _dishesFor(MealType mealType, int round) =>
      switch (mealType) {
        MealType.sang => [
            _dish('Cháo yến mạch thịt bằm $round',
                type: MealDishType.chaoSup, kcal: 360),
            _dish('Bún riêu cua ít muối $round',
                type: MealDishType.monNuoc, kcal: 410),
          ],
        MealType.trua => [
            _dish('Cơm gạo lứt & ức gà hấp $round',
                type: MealDishType.com, kcal: 460),
            _dish('Canh bí xanh nấu thịt nạc $round',
                type: MealDishType.monNuoc, kcal: 390),
          ],
        MealType.toi => [
            _dish('Cá hồi áp chảo & rau luộc $round',
                type: MealDishType.monHapLuoc, kcal: 440),
            _dish('Đậu hũ non sốt nấm $round',
                type: MealDishType.monMan, kcal: 380),
          ],
      };

  static MealDish _dish(
    String name, {
    required MealDishType type,
    required int kcal,
  }) =>
      MealDish(
        name: name,
        dishType: type,
        isNew: true,
        tags: const ['Ít muối', 'Dễ tiêu'],
        kcalEstimate: kcal,
        cookMinutes: 20,
        image: null,
        benefits: const [
          MealBenefit(
            text: 'Phù hợp chế độ ăn kiểm soát muối và chất béo bão hòa',
            type: 'condition',
            label: 'Sức khỏe tổng quát',
          ),
          MealBenefit(text: 'Cân bằng chất xơ và đạm dễ hấp thu', type: 'general'),
        ],
        ingredients: const [
          MealIngredient(
            name: 'Nguyên liệu chính',
            amount: '120 g',
            isMain: true,
            useSparingly: false,
          ),
          MealIngredient(
            name: 'Rau xanh theo mùa',
            amount: '100 g',
            isMain: true,
            useSparingly: false,
          ),
          MealIngredient(
            name: 'Muối ăn',
            amount: '¼ thìa cà phê',
            isMain: false,
            useSparingly: true,
          ),
        ],
      );

  @override
  Future<List<MealDishImage>> imageStates(List<int> imageIds) async {
    final remote = _remote;
    if (remote != null) return remote.imageStates(imageIds);
    return const [];
  }

  @override
  Future<Uint8List> imageBytes(MealDishImage image) async {
    final remote = _remote;
    if (remote != null) return remote.imageBytes(image);
    throw const MealSuggestionFailure(MealFailureKind.unknown);
  }
}

/// MOCK(6.11): Hồ sơ dị ứng của người bệnh được theo dõi cho tới khi backend `6.11`
/// cung cấp dữ liệu dị ứng theo `patient_id`.
class FamilyAllergyProfileRepository implements AllergyProfileRepository {
  FamilyAllergyProfileRepository({
    required this.patientId,
    this.accessCheck,
    AllergyProfile? profile,
  }) : _profile = profile ??
            const AllergyProfile(status: AllergyStatus.noneKnown);

  final String patientId;
  final FamilyMealAccessCheck? accessCheck;
  final AllergyProfile _profile;

  @override
  Future<AllergyProfile> load() async {
    final failure = accessCheck?.call(patientId);
    if (failure != null) {
      throw MealSuggestionFailure(failure);
    }
    return _profile;
  }
}
